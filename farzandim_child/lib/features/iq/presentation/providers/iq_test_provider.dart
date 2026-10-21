// IQ test yechish holati. Sessiya serverdan (yangi yoki davom etayotgan —
// birinchi javobsiz savoldan). Javob darhol saqlanadi (optimistik; xato
// bo'lsa oldingi tanlov qaytadi). Saqlashlar navbat bilan ketadi.

import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/providers/iq_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IqRunState {
  const IqRunState({
    required this.session,
    required this.index,
    this.isCompleting = false,
    this.error,
  });

  final IqSession session;
  final int index;
  final bool isCompleting;

  /// Oxirgi saqlash / yakunlash xatosi (UI qisqa xabar ko'rsatadi).
  final IqErrorCode? error;

  IqItem get current => session.items[index];
  bool get isFirst => index == 0;
  bool get isLast => index == session.items.length - 1;

  IqRunState copyWith({
    IqSession? session,
    int? index,
    bool? isCompleting,
    IqErrorCode? error,
    bool clearError = false,
  }) => IqRunState(
    session: session ?? this.session,
    index: index ?? this.index,
    isCompleting: isCompleting ?? this.isCompleting,
    error: clearError ? null : (error ?? this.error),
  );
}

final iqTestProvider =
    AsyncNotifierProvider.autoDispose<IqTestNotifier, IqRunState>(
      IqTestNotifier.new,
    );

class IqTestNotifier extends AutoDisposeAsyncNotifier<IqRunState> {
  final _clock = Stopwatch();

  /// Oxirgi saqlash (navbat) — keyingisi va yakunlash uni kutadi.
  Future<void>? _pending;

  IqRepository get _repo => ref.read(iqRepositoryProvider);

  @override
  Future<IqRunState> build() async {
    final session = await _repo.startSession();
    _clock
      ..reset()
      ..start();
    return IqRunState(session: session, index: session.resumeIndex);
  }

  void goTo(int index) {
    final s = state.valueOrNull;
    if (s == null || index < 0 || index >= s.session.items.length) return;
    _clock
      ..reset()
      ..start();
    state = AsyncData(s.copyWith(index: index, clearError: true));
  }

  Future<void> select(String key) {
    final s = state.valueOrNull;
    if (s == null || !s.session.isOpen || s.isCompleting) {
      return _pending ?? Future.value();
    }
    final index = s.index;
    final item = s.current;
    final previousChoice = item.choice;
    state = AsyncData(
      s.copyWith(
        session: s.session.withItem(index, item.withChoice(key)),
        clearError: true,
      ),
    );
    final elapsed = _clock.elapsedMilliseconds;
    final before = _pending;
    final save = () async {
      if (before != null) await before;
      try {
        await _repo.saveAnswer(
          sessionId: s.session.id,
          itemId: item.id,
          choice: key,
          durationMs: elapsed,
        );
      } on IqException catch (e) {
        final now = state.valueOrNull;
        if (now == null) return;
        final current = now.session.items[index];
        state = AsyncData(
          now.copyWith(
            session: now.session.withItem(
              index,
              current.withChoice(previousChoice),
            ),
            error: e.code,
          ),
        );
      }
    }();
    _pending = save;
    return save;
  }

  /// Yakunlash: navbatdagi saqlashlar tugagach; natija shu holatga yoziladi.
  Future<void> complete() async {
    final s = state.valueOrNull;
    if (s == null || s.isCompleting || !s.session.isAllAnswered) return;
    state = AsyncData(s.copyWith(isCompleting: true, clearError: true));
    await _pending;
    try {
      final done = await _repo.completeSession(s.session.id);
      state = AsyncData(IqRunState(session: done, index: 0));
      ref.invalidate(iqOverviewByAccountProvider);
    } on IqException catch (e) {
      final now = state.valueOrNull ?? s;
      state = AsyncData(now.copyWith(isCompleting: false, error: e.code));
    }
  }
}
