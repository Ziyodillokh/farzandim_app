// ─────────────────────────────────────────────────────────────────────
// unlock_request_provider — "Ruxsat so'rash" oqimi (Riverpod)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/unlock_request_bridge.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/widgets/unlock_request_modal.dart';
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native overlay/ogohlantirish → modal → backend so'rov ko'prigi.
///
/// Bloklangan ilovada "Ruxsat so'rash" (yoki "vaqting tugayapti" notification)
/// Parvoz'ni ochadi; bu yerda avval bolaga modal ko'rsatamiz (so'ralgan vaqt +
/// sabab), keyin backend'ga so'rov yuboramiz va natija snackbar'ini chiqaramiz.
final unlockRequestBridgeProvider = Provider<UnlockRequestBridge>((ref) {
  final repo = ref.watch(backendUnlockRequestRepositoryProvider);

  return UnlockRequestBridge((packageName) async {
    final ctx = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (ctx == null || !ctx.mounted) return;

    // Bola qancha vaqt va nima uchun so'rashini kiritadi.
    final input = await UnlockRequestModal.show(ctx);
    if (input == null || !ctx.mounted) return; // bekor qildi

    final ok = await repo.createRequest(
      kind: 'APP',
      packageName: packageName,
      requestedMinutes: input.minutes,
      reason: input.reason,
    );
    if (!ctx.mounted) return;
    if (ok) {
      AppSnackBar.info(ctx, 'unlockRequest.sent'.tr());
    } else {
      AppSnackBar.error(ctx, 'unlockRequest.sendError'.tr());
    }
  });
});

/// App ochilganда bir marta — native kutilayotgan unlock so'rovini tekshiradi.
/// `main.dart` ChildApp'da `ref.watch(unlockPendingCheckProvider)`.
final unlockPendingCheckProvider = FutureProvider<void>((ref) async {
  await ref.read(unlockRequestBridgeProvider).checkPending();
});
