// ─────────────────────────────────────────────────────────────────────
// quiz_provider — konkurs savol-javob StateNotifier
// ─────────────────────────────────────────────────────────────────────
//
// `family` ContestModel asosida — har konkurs uchun alohida instance.
// Auto-tarmoq:
//   loading 1.5s → backend questions fetch + startAttempt
//   intro → playing → (answer feedback 1.5s → next yoki finished)
//
// Sprint 5.7d: real backend ulanishi
//   - _start() — fetchQuestions(contest.id) → state.questions
//   - startPlaying() — startAttempt() → _attemptId
//   - _finish() — submitAttempt() → backend score (canonical) o'rnatadi
//   - MockQuestions fallback agar backend yetkazib bera olmasa
//
// Timer'lar:
//   _questionTimer — har savol uchun (40 sek default)
//   _totalTimer    — umumiy elapsed
//   _feedbackTimer — javobdan keyingi 1.5 sek delay

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Timer? _questionTimer;
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
      status: QuizStatus.intro,
      questions: questions,
      answers: List<int?>.filled(n, null),
    );
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
    state = state.copyWith(
      status: QuizStatus.playing,
      timeRemaining: _perQuestionSeconds,
    );
    _startQuestionTimer();
    _startTotalTimer();
    // Backend attempt yaratish (idempotent — bola bir konkursda 1 attempt)
    unawaited(_startBackendAttempt());
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

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.timeRemaining <= 1) {
        timer.cancel();
        _onTimeout();
      } else {
        state = state.copyWith(timeRemaining: state.timeRemaining - 1);
      }
    });
  }

  void _startTotalTimer() {
    _totalTimer?.cancel();
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      state = state.copyWith(
        totalElapsed: state.totalElapsed + const Duration(seconds: 1),
      );
    });
  }

  void selectAnswer(int index) {
    if (state.answerState != AnswerState.none) return;
    if (state.status != QuizStatus.playing) return;

    _questionTimer?.cancel();

    // Sprint 5.7e: Backend mode — correctIndex backend tomonida sir.
    // _attemptId mavjud va correctIndex < 0 bo'lsa per-question validation
    // chaqiramiz va backend javobiga qarab feedback ko'rsatamiz.
    final qid = state.currentQuestion.id;
    final qLooksLikeUuid = qid.length >= 32;
    if (_attemptId != null &&
        qLooksLikeUuid &&
        state.currentQuestion.correctIndex < 0) {
      unawaited(_selectAnswerBackend(index));
      return;
    }

    // Mock mode — lokal correctIndex bilan tekshirish (eski xulq).
    _applyAnswer(
      selectedIndex: index,
      isCorrect: index == state.currentQuestion.correctIndex,
      bonus: state.currentQuestion.bonus,
    );
  }

  Future<void> _selectAnswerBackend(int index) async {
    final attemptId = _attemptId;
    if (attemptId == null) return;

    // Optimistic "selected" feedback (neutral) — feedback rangi backend
    // javobidan keyin keladi.
    final answers = [...state.answers];
    answers[state.currentIndex] = index;
    state = state.copyWith(selectedAnswer: index, answers: answers);

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
  void _applyAnswer({
    required int selectedIndex,
    required bool isCorrect,
    required int bonus,
    int? overrideTotalScore,
  }) {
    final answers = [...state.answers];
    answers[state.currentIndex] = selectedIndex;

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
      );
    } else {
      state = state.copyWith(
        selectedAnswer: selectedIndex,
        answerState: AnswerState.wrong,
        totalScore: overrideTotalScore ?? state.totalScore,
        wrongCount: state.wrongCount + 1,
        currentStreak: 0,
        answers: answers,
      );
    }

    // Har javobda fresh timer — avval `??=` ishlatilgani uchun 1-savoldan
    // keyin `_feedbackTimer` non-null qolib, quiz 2-savolда qotardi.
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _onTimeout() {
    final answers = [...state.answers];
    answers[state.currentIndex] = null;

    state = state.copyWith(
      answerState: AnswerState.timeout,
      wrongCount: state.wrongCount + 1,
      currentStreak: 0,
      answers: answers,
    );

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (state.isLastQuestion) {
      _finish();
      return;
    }

    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(
      currentIndex: nextIndex,
      clearSelected: true,
      answerState: AnswerState.none,
      timeRemaining: _perQuestionSeconds,
    );

    _startQuestionTimer();
  }

  void _finish() {
    _questionTimer?.cancel();
    _totalTimer?.cancel();
    state = state.copyWith(status: QuizStatus.finished);

    // Backend submit (canonical score)
    unawaited(_submitBackendAttempt());

    // G'olib bonus XP — UI bilan AYNI chegara (QuizState.winnerThreshold).
    if (state.isWinner) {
      unawaited(_awardWinnerXp());
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
    _questionTimer?.cancel();
    _totalTimer?.cancel();
    state = state.copyWith(status: QuizStatus.paused);
  }

  void resume() {
    state = state.copyWith(status: QuizStatus.playing);
    _startQuestionTimer();
    _startTotalTimer();
  }

  void quit() {
    _questionTimer?.cancel();
    _totalTimer?.cancel();
    _feedbackTimer?.cancel();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _totalTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }
}

final quizProvider =
    StateNotifierProvider.family<QuizNotifier, QuizState, ContestModel>(
      (ref, contest) => QuizNotifier(ref, contest),
    );
