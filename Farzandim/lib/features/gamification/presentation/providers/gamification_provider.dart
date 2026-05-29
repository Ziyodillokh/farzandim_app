// ─────────────────────────────────────────────────────────────────────
// gamification_provider — Bola gamification state (Sprint 4.4.6)
// ─────────────────────────────────────────────────────────────────────
//
// Backend `/api/children/:childId/profile` + WS `profile:updated`.
// Parent App "Bola yutuqlari" ekrani uchun.

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/gamification/data/repositories/backend_gamification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola gamification profili — Backend fetch + WS real-time refresh.
final childProfileProvider =
    StreamProvider.family<ChildProfile?, String>((ref, childId) async* {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) {
    yield null;
    return;
  }

  final repo = ref.watch(backendGamificationRepositoryProvider);
  yield await repo.getProfile(childId);

  // WS `profile:updated` — XP/Level o'zgarsa refresh.
  final controller = StreamController<ChildProfile?>();
  final sub = repo.profileUpdatedStream().listen((data) async {
    if (data is Map && data['childId'] == childId) {
      final fresh = await repo.getProfile(childId);
      if (!controller.isClosed) controller.add(fresh);
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// XP events history (Bola yutuqlari ekranida tarix).
final childXpEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, childId) async {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) return const [];
  final repo = ref.watch(backendGamificationRepositoryProvider);
  return repo.getXpEvents(childId: childId, limit: 50);
});
