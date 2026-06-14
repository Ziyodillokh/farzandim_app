// ─────────────────────────────────────────────────────────────────────
// fcm_provider — Child App FCM service Riverpod (Sprint 4.4.8)
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FcmService singleton — Backend FCM repository bilan.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    backendRepo: ref.watch(backendFcmRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// `unlock_decision` push kelganda — limit qayta sync + bolaga snackbar.
/// APPROVED → success ("X daqiqa ruxsat"); DENIED → info ("rad etildi").
void _handleUnlockDecision(Ref ref, RemoteMessage message) {
  if (message.data['type'] != 'unlock_decision') return;
  // Limit darhol yangilansin (server effektiv limitga grantni qo'shgan).
  unawaited(ref.read(restrictionsSyncServiceProvider).sync());

  final ctx =
      ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final approved = message.data['approved'] == 'true';
  if (approved) {
    final mins = message.data['grantedMinutes'] ?? '';
    AppSnackBar.success(
      ctx,
      'Ota-onangiz $mins daqiqa qo\'shimcha vaqt berdi!',
    );
  } else {
    AppSnackBar.info(ctx, "So'rovingiz rad etildi.");
  }
}

/// FCM tizimini ishga tushirish — `app.dart` (yoki main) bir marta
/// `ref.watch(fcmInitializerProvider)` chaqiradi.
final fcmInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.read(fcmServiceProvider);
  // Foreground + tap'da unlock qarorини qayta ishlaymiz (limit sync + UI).
  service.onForegroundMessage = (msg) => _handleUnlockDecision(ref, msg);
  service.onMessageTap = (msg) => _handleUnlockDecision(ref, msg);
  await service.init();
});
