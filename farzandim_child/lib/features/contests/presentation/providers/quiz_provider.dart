// ─────────────────────────────────────────────────────────────────────
// quiz_provider — konkurs savol-javob StateNotifier
// ─────────────────────────────────────────────────────────────────────
//
// `family` ContestModel asosida — har konkurs uchun alohida instance.
// Oqim: loading → (auto) playing. Navigatsiya MANUAL (goNext/goPrevious),
// javob berilganda auto-advance YO'Q. Timer UMUMIY (byudjet = per-savol vaqti
// × savollar soni); `timeRemaining` = umumiy qolgan vaqt, 0 da yakunlaydi.
//
// Backend: _start() fetchQuestions → startPlaying() startAttempt →
// selectAnswer() per-savol validatsiya → _finish() submitAttempt (canonical
// score). MockQuestions fallback agar backend yetkazib bera olmasa.
//
// Timer'lar:
//   _totalTimer    — umumiy vaqt (elapsed + qolgan)
//   _feedbackTimer — backend attemptFinished bo'lsa yakunlash delay'i

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/contests/data/mock_questions.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/question_model.dart';
import 'package:farzandim_child/features/contests/data/models/quiz_state.dart';
import 'package:farzandim_child/features/contests/data/models/test_difficulty.dart';
import 'package:farzandim_child/features/contests/data/repositories/contests_backend_repository.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/gamification/data/models/xp_event.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

class QuizNotifier extends StateNotifier<QuizState> {
  QuizNotifier(this._ref, this.contest) : super(const QuizState()) {
    _start();
  }

  /// Riverpod ref — XpService, pairingStateProvider va backend repoga kirish.
  final Ref _ref;

  final ContestModel contest;

  /// Tanlangan qiyinlikdan per-savol soniya ("Konkurs shartlari" sheet).
  /// Boshlashdan oldin sheet `selectedTestDifficultyProvider`ni yozadi.
  late final int _perQuestionSeconds = _ref
      .read(selectedTestDifficultyProvider)
      .secondsPerQuestion;

  Timer? _totalTimer;
  Timer? _feedbackTimer;

  /// Backend OlympiadAttempt id. _start() paytida olinadi.
  String? _attemptId;

  /// XP yutilganmi yo'qmi — har konkursga bir martagacha cheklash uchun
  /// dedup `relatedId: contest.id` orqali ham qilinadi (XpService dedup),
  /// lekin local flag chaqirishni qisqartirish uchun.
  bool _joinedXpAwarded = false;
  bool _winnerXpAwarded = false;

  Future<void> _start() async {
    state = state.copyWith(status: QuizStatus.loading);
    // Backend'dan questions yuklash (fallback mock agar fail bo'lsa)
    final repo = _ref.read(contestsBackendRepositoryProvider);
    final questions = await _safeLoadQuestions(repo);
    if (!mounted) return;
    final n = questions.isNotEmpty
        ? questions.length
        : MockQuestions.all.length;
    state = state.copyWith(
      questions: questions,
      answers: List<int?>.filled(n, null),
      results: List<AnswerState>.filled(n, AnswerState.none),
      correctIndices: List<int?>.filled(n, null),
    );
    // Backend attempt AVVAL boshlanadi — savolga javob berishdan oldin
    // _attemptId tayyor bo'lsin. Aks holda backend savol (correctIndex sir)
    // mock -1 yo'liga tushib HAR DOIM xato hisoblanardi. "Konkurs shartlari"
    // sheet allaqachon ko'rsatildi — alohida intro ekran yo'q.
    await _startBackendAttempt();
    if (!mounted) return;
    startPlaying();
  }

  Future<List<QuestionModel>> _safeLoadQuestions(
    ContestsBackendRepository repo,
  ) async {
    try {
      final q = await repo.fetchQuestions(contest.id);
      return q;
    } catch (e) {
      debugPrint('Quiz: backend questions fetch failed → mock fallback: $e');
      return const [];
    }
  }

  void startPlaying() {
    // `timeRemaining` endi UMUMIY qolgan vaqt (har savol vaqti × savollar
    // soni). Header'da 12:32 ko'rinishida sanaydi, 0 da yakunlaydi.
    final budget = _perQuestionSeconds * state.effectiveQuestions.length;
    state = state.copyWith(status: QuizStatus.playing, timeRemaining: budget);
    _startTotalTimer();
    // Backend attempt _start()da AVVAL boshlangan (idempotent).
    // Boshlangach darhol "contestJoined" XP — Konsept v2 4.2: +30 XP, +5 DON
    unawaited(_awardJoinedXp());
  }

  Future<void> _startBackendAttempt() async {
    if (_attemptId != null) return;
    try {
      final repo = _ref.read(contestsBackendRepositoryProvider);
      final id = await repo.startAttempt(contest.id);
      _attemptId = id;
      // Sertifikat (#56) uchun attempt ID'ni state'ga ham yozamiz.
      state = state.copyWith(attemptId: id);
      debugPrint('Quiz: attempt started id=$id');
    } catch (e) {
      debugPrint('Quiz: startAttempt failed: $e');
    }
  }

  Future<void> _awardJoinedXp() async {
    if (_joinedXpAwarded) return;
    _joinedXpAwarded = true;

    final pairing = _ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;

    try {
      await _ref
          .read(xpServiceProvider)
          .awardXp(
            parentUid: parentUid,
            childId: childId,
            type: XpEventType.contestJoined,
            relatedId: contest.id,
          );
    } catch (e) {
      // XP yutuq fail bo'lsa quiz davom etadi — log + ignore.
      debugPrint('XP award (contest_joined) error: $e');
    }
  }

  Future<void> _awardWinnerXp() async {
    if (_winnerXpAwarded) return;
    _winnerXpAwarded = true;

    final pairing = _ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;

    try {
      final xpService = _ref.read(xpServiceProvider);

      await xpService.awardXp(
        parentUid: parentUid,
        childId: childId,
        type: XpEventType.contestWon,
        relatedId: contest.id,
      );

      // XP yutilgach achievement check — yangi unlock'lar bo'lsa
      // notifier'dan oqib chiqadi (gamification profile stream'da
      // unlockedAchievements ro'yxati o'sganda UI snackbar ko'rsatadi).
      await xpService.buildContextAndCheck(
        parentUid: parentUid,
        childId: childId,
      );
    } catch (e) {
      debugPrint('XP award (contest_won) error: $e');
    }
  }

  // Umumiy quiz timeri — `timeRemaining` (byudjet) 0 ga yetsa yakunlaydi.
  void _startTotalTimer() {
    _totalTimer?.cancel();
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = state.timeRemaining - 1;
      state = state.copyWith(
        totalElapsed: state.totalElapsed + const Duration(seconds: 1),
        timeRemaining: remaining < 0 ? 0 : remaining,
      );
      if (remaining <= 0) _finish();
    });
  }

  void selectAnswer(int index) {
    if (state.answerState != AnswerState.none) return;
    if (state.status != QuizStatus.playing) return;

    final q = state.currentQuestion;
    // Backend savol = UUID id (>=32) + correctIndex sir (-1). Bunday savol
    // HAR DOIM backend orqali tekshiriladi (attempt hali tayyor bo'lmasa
    // _selectAnswerBackend uni kutadi). Avval "_attemptId != null" sharti bor
    // edi — attempt tayyor bo'lmaguncha mock -1 yo'liga tushib HAMMA javob
    // xato hisoblanardi.
    final isBackendQuestion = q.id.length >= 32 && q.correctIndex < 0;
    if (isBackendQuestion) {
      unawaited(_selectAnswerBackend(index));
      return;
    }

    // Mock savol — lokal correctIndex bilan tekshiriladi.
    _applyAnswer(
      selectedIndex: index,
      isCorrect: index == q.correctIndex,
      bonus: q.bonus,
      correctIndex: q.correctIndex,
    );
  }

  Future<void> _selectAnswerBackend(int index) async {
    // Attempt hali tayyor emas — kutamiz (auto-start race'ini yopadi).
    if (_attemptId == null) await _startBackendAttempt();
    if (!mounted) return;

    // Optimistic "selected" feedback (neutral) — feedback rangi backend
    // javobidan keyin keladi.
    final answers = [...state.answers];
    answers[state.currentIndex] = index;
    state = state.copyWith(selectedAnswer: index, answers: answers);

    final attemptId = _attemptId;
    if (attemptId == null) {
      // Attempt boshlanmadi (offline/xato) — final submit'ga qoldiramiz.
      // Javob berilgan deb belgilaymiz (natija noaniq).
      _applyAnswer(selectedIndex: index, isCorrect: false, bonus: 0);
      return;
    }

    final repo = _ref.read(contestsBackendRepositoryProvider);
    final feedback = await repo.submitSingleAnswer(
      attemptId: attemptId,
      questionId: state.currentQuestion.id,
      selectedIndex: index,
    );

    if (!mounted) return;

    // Tarmoq xato — neutral feedback bilan oldinga (yo'qotmaslik uchun)
    if (feedback == null) {
      _applyAnswer(selectedIndex: index, isCorrect: false, bonus: 0);
      return;
    }

    if (feedback.timeExpired) {
      state = state.copyWith(
        status: QuizStatus.finished,
        answerState: AnswerState.timeout,
      );
      return;
    }

    _applyAnswer(
      selectedIndex: index,
      isCorrect: feedback.isCorrect,
      bonus: feedback.points,
      // Backend ochgan to'g'ri variant (>=0 bo'lsa) — noto'g'ri belgilanganda
      // yashil ko'rsatiladi.
      correctIndex: feedback.correctIndex >= 0 ? feedback.correctIndex : null,
      // Backend canonical scoreSoFar ham ishlatamiz (totalScore'ni
      // increment qilish o'rniga to'g'ridan-to'g'ri o'rnatamiz).
      overrideTotalScore: feedback.scoreSoFar,
    );

    // Backend attemptFinished bo'lsa darhol _finish() chaqiramiz
    if (feedback.attemptFinished && state.status != QuizStatus.finished) {
      _feedbackTimer = Timer(const Duration(milliseconds: 1500), _finish);
    }
  }

  /// Common feedback applier — mock va backend ikkalasi shu yerga keladi.
  /// `correctIndex` — ochilgan to'g'ri variant (noto'g'ri belgilanganda uni
  /// yashil ko'rsatish uchun); noma'lum bo'lsa null.
  void _applyAnswer({
    required int selectedIndex,
    required bool isCorrect,
    required int bonus,
    int? correctIndex,
    int? overrideTotalScore,
  }) {
    final answers = [...state.answers];
    answers[state.currentIndex] = selectedIndex;
    final results = [...state.results];
    results[state.currentIndex] = isCorrect
        ? AnswerState.correct
        : AnswerState.wrong;
    final correctIndices = [...state.correctIndices];
    // To'g'ri belgilangan bo'lsa to'g'ri = tanlangan; aks holda backend/mock
    // bergan indeks (null bo'lsa ochilmaydi).
    correctIndices[state.currentIndex] = isCorrect
        ? selectedIndex
        : correctIndex;

    if (isCorrect) {
      final newStreak = state.currentStreak + 1;
      state = state.copyWith(
        selectedAnswer: selectedIndex,
        answerState: AnswerState.correct,
        totalScore: overrideTotalScore ?? (state.totalScore + bonus),
        correctCount: state.correctCount + 1,
        currentStreak: newStreak,
        maxStreak: newStreak > state.maxStreak ? newStreak : state.maxStreak,
        answers: answers,
        results: results,
        correctIndices: correctIndices,
      );
    } else {
      state = state.copyWith(
        selectedAnswer: selectedIndex,
        answerState: AnswerState.wrong,
        totalScore: overrideTotalScore ?? state.totalScore,
        wrongCount: state.wrongCount + 1,
        currentStreak: 0,
        answers: answers,
        results: results,
        correctIndices: correctIndices,
      );
    }
    // Auto-advance YO'Q — foydalanuvchi "Keyingi" tugmasi bilan o'tadi.
  }

  /// Keyingi savol — oxirgisida yakunlaydi. Javob berilgan savolga qaytilsa
  /// (Oldingi) o'sha holat (to'g'ri/noto'g'ri) tiklanadi (faqat o'qish).
  void goNext() {
    if (!mounted) return;
    if (state.currentIndex >= state.effectiveQuestions.length - 1) {
      _finish();
      return;
    }
    _goTo(state.currentIndex + 1);
  }

  /// Oldingi savol (ko'rib chiqish).
  void goPrevious() {
    if (!mounted || state.currentIndex <= 0) return;
    _goTo(state.currentIndex - 1);
  }

  void _goTo(int index) {
    final sel = index < state.answers.length ? state.answers[index] : null;
    final res = index < state.results.length
        ? state.results[index]
        : AnswerState.none;
    state = state.copyWith(
      currentIndex: index,
      answerState: res,
      selectedAnswer: sel,
      clearSelected: sel == null,
    );
  }

  void _finish() {
    _totalTimer?.cancel();
    _feedbackTimer?.cancel();
    state = state.copyWith(status: QuizStatus.finished);

    // Backend submit (canonical score)
    unawaited(_submitBackendAttempt());

    // G'olib bonus XP — UI bilan AYNI chegara (QuizState.winnerThreshold).
    if (state.isWinner) {
      unawaited(_awardWinnerXp());
    }

    // Shaxsiy rekord (lokal) — "Natija" kartasidagi "Rekord".
    unawaited(_persistRecord());
  }

  /// Bu test bo'yicha eng ko'p to'g'ri javob (lokal) — yangilaydi + state'ga.
  Future<void> _persistRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'test_record_${contest.id}';
      final prev = prefs.getInt(key) ?? 0;
      final best = state.correctCount > prev ? state.correctCount : prev;
      if (best != prev) await prefs.setInt(key, best);
      if (!mounted) return;
      state = state.copyWith(recordCorrect: best);
    } catch (_) {
      // Xato — rekord ko'rsatilmaydi (correctCount fallback).
    }
  }

  Future<void> _submitBackendAttempt() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;
    final questions = state.effectiveQuestions;
    final answers = <AttemptAnswer>[];
    for (var i = 0; i < state.answers.length && i < questions.length; i += 1) {
      final selected = state.answers[i];
      if (selected == null) continue;
      final qid = questions[i].id;
      // Mock question id (`q1`, `q2`, ...) UUID emas — backend reject qiladi.
      if (qid.length < 32) continue;
      answers.add(AttemptAnswer(questionId: qid, selectedIndex: selected));
    }
    if (answers.isEmpty) return;
    try {
      final repo = _ref.read(contestsBackendRepositoryProvider);
      final result = await repo.submitAttempt(
        attemptId: attemptId,
        answers: answers,
        timeSec: state.totalElapsed.inSeconds,
      );
      debugPrint('Quiz: backend submit result $result');
    } catch (e) {
      debugPrint('Quiz: submit failed: $e');
    }
  }

  void pause() {
    _totalTimer?.cancel();
    state = state.copyWith(status: QuizStatus.paused);
  }

  void resume() {
    state = state.copyWith(status: QuizStatus.playing);
    _startTotalTimer();
  }

  void quit() {
    _totalTimer?.cancel();
    _feedbackTimer?.cancel();
  }

  @override
  void dispose() {
    _totalTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }
}

final quizProvider =
    StateNotifierProvider.family<QuizNotifier, QuizState, ContestModel>(
      (ref, contest) => QuizNotifier(ref, contest),
    );
