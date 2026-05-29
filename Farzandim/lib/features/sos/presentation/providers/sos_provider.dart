// ─────────────────────────────────────────────────────────────────────
// sos_provider — SOS alerts state (Sprint 4.4.7)
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/sos/data/repositories/backend_sos_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SOS alerts ro'yxati statusga qarab — Backend fetch + WS refresh.
///
/// `status`: 'ACTIVE' (faol alertlar) | 'RESOLVED' (tarix).
final sosAlertsByStatusProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, status) async* {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) {
    yield const [];
    return;
  }

  final repo = ref.watch(backendSosRepositoryProvider);
  yield await repo.getAlerts(status: status);

  final controller = StreamController<List<Map<String, dynamic>>>();
  Future<void> refresh() async {
    if (controller.isClosed) return;
    final list = await repo.getAlerts(status: status);
    if (!controller.isClosed) controller.add(list);
  }

  final receivedSub = repo.receivedStream().listen((_) => refresh());
  final resolvedSub = repo.resolvedStream().listen((_) => refresh());

  ref.onDispose(() {
    receivedSub.cancel();
    resolvedSub.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// Faol SOS alerts (qisqartma — `sosAlertsByStatusProvider('ACTIVE')`).
final activeSosAlertsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => ref.watch(sosAlertsByStatusProvider('ACTIVE')),
);

/// Hal qilingan SOS alerts (tarix).
final resolvedSosAlertsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => ref.watch(sosAlertsByStatusProvider('RESOLVED')),
);

/// SOS alert WS push stream — Parent App'da global notification banner.
/// Payload: `{ sosAlertId, childId, lat, lng, ... }`.
final sosReceivedAlertProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) return const Stream.empty();
  final repo = ref.watch(backendSosRepositoryProvider);
  return repo
      .receivedStream()
      .map((data) => data is Map<String, dynamic> ? data : <String, dynamic>{})
      .where((m) => m.isNotEmpty);
});
