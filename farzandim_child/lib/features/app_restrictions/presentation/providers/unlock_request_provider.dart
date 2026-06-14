// ─────────────────────────────────────────────────────────────────────
// unlock_request_provider — "Ruxsat so'rash" oqimi (Riverpod)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/unlock_request_bridge.dart';
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native overlay → backend so'rov ko'prigi. So'rov yuborilgach bolaga
/// "kutilmoqda" snackbar ko'rsatadi (router global context orqali).
final unlockRequestBridgeProvider = Provider<UnlockRequestBridge>((ref) {
  final repo = ref.watch(backendUnlockRequestRepositoryProvider);

  return UnlockRequestBridge((packageName) async {
    final ok = await repo.createRequest(kind: 'APP', packageName: packageName);
    final ctx =
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    if (ok) {
      AppSnackBar.info(
        ctx,
        "So'rov yuborildi. Ota-onangiz qarorini kuting…",
      );
    } else {
      AppSnackBar.error(
        ctx,
        "So'rovni yuborib bo'lmadi. Qaytadan urinib ko'ring.",
      );
    }
  });
});

/// App ochilganда bir marta — native kutilayotgan unlock so'rovini tekshiradi.
/// `main.dart` ChildApp'da `ref.watch(unlockPendingCheckProvider)`.
final unlockPendingCheckProvider = FutureProvider<void>((ref) async {
  await ref.read(unlockRequestBridgeProvider).checkPending();
});
