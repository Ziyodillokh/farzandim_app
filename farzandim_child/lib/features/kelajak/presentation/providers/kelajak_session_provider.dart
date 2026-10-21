// Kelajak testini yechish — sessiya notifier'i (test turi bo'yicha).
//
//   • Ochilganda bugungi sessiya boshlanadi yoki davom ettiriladi (server
//     idempotent: qayta ochish / ilova qayta ishga tushishi o'sha sessiyani
//     javoblari bilan qaytaradi).
//   • Javob — darhol ekranda (optimistik) va PUT; xato bo'lsa server
//     tasdiqlagan javobga qaytariladi va xato holati beriladi.
//   • Eskirgan javoblar e'tiborsiz: har savol so'rovlari tartib raqamli —
//     ekranni faqat eng so'nggi so'rov natijasi belgilaydi; sessiya qayta
//     yuklansa yoki sahifa yopilsa, eski so'rov javoblari tashlanadi.
//   • Ochiq matn har harfda emas — "Keyingi" yoki maydondan chiqishda
//     (`saveText`) saqlanadi.

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_run_state.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_results_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test turi (`daily`, `career` …) bo'yicha bugungi sessiya. Sahifa
/// yopilganda tashlanadi — javoblar xotirada qolmaydi.
final kelajakSessionProvider = AsyncNotifierProvider.autoDispose
    .family<KelajakSessionNotifier, KelajakRunState, String>(
      KelajakSessionNotifier.new,
    );

class KelajakSessionNotifier
    extends AutoDisposeFamilyAsyncNotifier<KelajakRunState, String> {
  /// Qayta yuklash / yopilishda oshadi — eski so'rov javoblari tashlanadi.
  int _generation = 0;

  /// Savol id → oxirgi yuborilgan so'rov tartib raqami.
  final _issued = <String, int>{};

  /// Savol id → yakunlangan eng so'nggi so'rov (= [_issued] — kutilayotgan
  /// so'rov yo'q).
  final _settled = <String, int>{};

  /// Server tasdiqlagan javoblar va ularning so'rov tartib raqami.
  Map<String, KelajakAnswer> _confirmed = const {};
  final _confirmedSeq = <String, int>{};

  KelajakRepository get _repository => ref.read(kelajakRepositoryProvider);

  @override
  Future<KelajakRunState> build(String type) async {
    ref.onDispose(() => _generation++);
    if (ref.watch(kelajakAccountProvider) == null) {
      throw const KelajakException(KelajakErrorCode.unavailable);
    }
    final session = await ref
        .watch(kelajakRepositoryProvider)
        .startSession(type);
    return _open(session);
  }

  /// Variant tanlash — darhol ekranda, keyin serverga.
  Future<void> select(String questionId, int value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = current.select(questionId, value);
    if (identical(next, current)) return;
    await _save(next, questionId, value: value);
  }

  /// Ochiq javobni saqlash ("Keyingi" / maydondan chiqishda). O'zgarmagan
  /// matn yuborilmaydi; bo'sh matn javobni o'chiradi.
  Future<void> saveText(String questionId, String text) async {
    final current = state.valueOrNull;
    final question = current?.question(questionId);
    if (current == null || question == null || !question.isText) return;
    if (text.trim().length > question.textLimit) {
      state = AsyncData(
        current.withError(
          const KelajakException(KelajakErrorCode.invalidAnswer),
        ),
      );
      return;
    }
    final next = current.writeText(questionId, text);
    if (identical(next, current)) return;
    await _save(next, questionId, text: next.answerFor(questionId)?.text ?? '');
  }

  void next() => _update((s) => s.next());

  void back() => _update((s) => s.back());

  void goTo(String questionId) => _update((s) => s.goTo(questionId));

  void clearError() => _update((s) => s.clearError());

  /// Yakunlash. `true` — natija tayyor (sessiya yakunlangan).
  Future<bool> complete() async {
    final current = state.valueOrNull;
    if (current == null) return false;
    final starting = current.startCompleting();
    if (identical(starting, current)) return current.isCompleted;
    final generation = _generation;
    state = AsyncData(starting);
    try {
      final done = await _repository.completeSession(current.sessionId);
      if (generation != _generation) return false;
      state = AsyncData((state.valueOrNull ?? starting).completed(done));
      _invalidateResults();
      return done.isCompleted;
    } on KelajakException catch (e) {
      if (generation != _generation) return false;
      state = AsyncData((state.valueOrNull ?? starting).completeFailed(e));
      return false;
    }
  }

  /// Qayta yuklash (bugungi sessiya). O'sha sessiya bo'lsa — joriy savolda
  /// qoladi; xato bo'lsa oldingi holat xato bilan saqlanadi.
  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final generation = ++_generation;
    state = const AsyncLoading<KelajakRunState>().copyWithPrevious(state);
    try {
      final session = await _repository.startSession(arg);
      if (generation != _generation) return;
      final focus = previous?.sessionId == session.id
          ? previous?.current.id
          : null;
      state = AsyncData(_open(session, focusQuestionId: focus));
    } on KelajakException catch (e, stack) {
      if (generation != _generation) return;
      state = previous == null
          ? AsyncError(e, stack)
          : AsyncData(previous.withError(e));
    }
  }

  KelajakRunState _open(KelajakSession session, {String? focusQuestionId}) {
    if (session.questions.isEmpty) {
      throw const KelajakException(KelajakErrorCode.noQuestions);
    }
    _issued.clear();
    _settled.clear();
    _confirmedSeq.clear();
    _confirmed = {for (final a in session.answers) a.questionId: a};
    _syncOverview(session.status);
    return KelajakRunState.fromSession(
      session,
      focusQuestionId: focusQuestionId,
    );
  }

  void _update(KelajakRunState Function(KelajakRunState state) change) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = change(current);
    if (!identical(next, current)) state = AsyncData(next);
  }

  Future<void> _save(
    KelajakRunState optimistic,
    String questionId, {
    int? value,
    String? text,
  }) async {
    final generation = _generation;
    final seq = (_issued[questionId] ?? 0) + 1;
    _issued[questionId] = seq;
    state = AsyncData(optimistic.startSaving(questionId).clearError());
    KelajakAnswerAck? ack;
    KelajakException? failure;
    try {
      ack = await _repository.saveAnswer(
        sessionId: optimistic.sessionId,
        questionId: questionId,
        value: value,
        text: text,
      );
    } on KelajakException catch (e) {
      failure = e;
    }
    if (generation != _generation) return;
    _settle(questionId, seq, ack);
    // Yangiroq so'rov hali kutilmoqda — ekranni o'sha belgilaydi.
    if (_settled[questionId] != _issued[questionId]) return;
    final latest = state.valueOrNull;
    if (latest == null) return;
    var next = latest
        .restore(questionId, _confirmed[questionId])
        .finishSaving(questionId);
    if (ack != null) next = next.withStatus(ack.sessionStatus);
    if (failure != null && seq == _issued[questionId]) {
      next = next.withError(failure);
      if (failure.code == KelajakErrorCode.sessionClosed) next = next.close();
    }
    state = AsyncData(next);
    if (next.status != latest.status) _syncOverview(next.status);
  }

  /// So'rov yakunlandi: muvaffaqiyatli javob eng so'nggi tasdiqlangandan
  /// yangiroq bo'lsa — u tasdiqlangan javob bo'ladi.
  void _settle(String questionId, int seq, KelajakAnswerAck? ack) {
    if (seq == _issued[questionId]) _settled[questionId] = seq;
    if (ack == null || seq <= (_confirmedSeq[questionId] ?? 0)) return;
    _confirmedSeq[questionId] = seq;
    final answer = ack.answer;
    _confirmed = answer == null
        ? {
            for (final e in _confirmed.entries)
              if (e.key != questionId) e.key: e.value,
          }
        : {..._confirmed, questionId: answer};
  }

  /// Overview'dagi bugungi holat eskirgan bo'lsa — qayta yuklanadi
  /// ("Bugungi testlar" kartasi yangilansin).
  void _syncOverview(KelajakSessionStatus status) {
    final account = ref.read(kelajakAccountProvider);
    if (account == null) return;
    final provider = kelajakOverviewByAccountProvider(account);
    if (!ref.exists(provider)) return;
    final known = ref.read(provider).valueOrNull?.testOf(arg)?.today.status;
    if (known == null || known.wire == status.wire) return;
    ref.invalidate(provider);
  }

  /// Yakunlangandan keyin: overview, rivojlanish va natijalar qayta yuklanadi.
  void _invalidateResults() {
    ref
      ..invalidate(kelajakOverviewByAccountProvider)
      ..invalidate(kelajakProgressProvider)
      ..invalidate(kelajakResultsProvider);
  }
}
