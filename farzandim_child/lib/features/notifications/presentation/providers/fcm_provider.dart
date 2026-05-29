// ─────────────────────────────────────────────────────────────────────
// fcm_provider — Child App FCM service Riverpod (Sprint 4.4.8)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FcmService singleton — Backend FCM repository bilan.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    backendRepo: ref.watch(backendFcmRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// FCM tizimini ishga tushirish — `app.dart` (yoki main) bir marta
/// `ref.watch(fcmInitializerProvider)` chaqiradi.
final fcmInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.read(fcmServiceProvider);
  await service.init();
});
