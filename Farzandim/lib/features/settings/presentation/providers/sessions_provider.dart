// ─────────────────────────────────────────────────────────────────────
// sessionsProvider — "Faol sessiyalar" holati (Sprint 7)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim/features/settings/data/models/user_session.dart';
import 'package:farzandim/features/settings/data/repositories/backend_session_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Faol sessiyalar ro'yxati + tugatish amallari.
final sessionsProvider =
    AutoDisposeAsyncNotifierProvider<SessionsNotifier, List<UserSession>>(
  SessionsNotifier.new,
);

class SessionsNotifier extends AutoDisposeAsyncNotifier<List<UserSession>> {
  @override
  Future<List<UserSession>> build() {
    return ref.watch(backendSessionRepositoryProvider).getSessions();
  }

  /// Qayta yuklash (pull-to-refresh / amal'dan keyin).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(backendSessionRepositoryProvider).getSessions(),
    );
  }

  /// Bitta sessiyani tugatish, keyin ro'yxatni yangilash.
  Future<void> revoke(String id) async {
    final repo = ref.read(backendSessionRepositoryProvider);
    await repo.revokeSession(id);
    state = AsyncValue.data(await repo.getSessions());
  }

  /// Joriydan boshqa barcha sessiyalarni tugatish.
  Future<void> revokeOthers() async {
    final repo = ref.read(backendSessionRepositoryProvider);
    await repo.revokeOthers();
    state = AsyncValue.data(await repo.getSessions());
  }
}
