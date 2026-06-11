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

  // MUHIM (P0-3 + P0-REG-2): controller va WS obunalar BIRINCHI fetch'dan
  // OLDIN o'rnatiladi. Avval birinchi fetch xato bo'lsa generator O'LARDI —
  // WS obunalar hech o'rnatilmay, provider doimiy AsyncError'da tiqilib
  // qolardi. Endi: birinchi xato addError orqali ekranga chiqadi (aniq
  // xato + retry), lekin stream OCHIQ qoladi — keyingi WS event yoki
  // retry AsyncData'ni tiklaydi.
  final controller = StreamController<List<Map<String, dynamic>>>();
  Future<void> refresh({bool surfaceError = false}) async {
    if (controller.isClosed) return;
    try {
      final list = await repo.getAlerts(status: status);
      if (!controller.isClosed) controller.add(list);
    } catch (e, st) {
      if (surfaceError && !controller.isClosed) {
        controller.addError(e, st);
      }
      // WS-triggered refresh xatosi (surfaceError=false) — oxirgi ro'yxat
      // saqlanadi.
    }
  }

  final receivedSub = repo.receivedStream().listen((_) => refresh());
  final resolvedSub = repo.resolvedStream().listen((_) => refresh());

  ref.onDispose(() {
    receivedSub.cancel();
    resolvedSub.cancel();
    controller.close();
  });

  // Birinchi yuklash — xatosi ekranga chiqadi (yolg'on "tinch" emas).
  unawaited(refresh(surfaceError: true));
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
