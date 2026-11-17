// ─────────────────────────────────────────────────────────────────────
// unlock_request_provider — "Ruxsat so'rash" oqimi (Riverpod)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/unlock_request_bridge.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/shell_ready_gate.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/widgets/unlock_request_modal.dart';
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola qo'shimcha vaqt so'raydi: modal (so'ralgan vaqt + sabab) → backend →
/// natija snackbar'i. [packageName] — Android'da bloklangan ilova ('APP');
/// iOS'da `null` — ilova nomi serverga yuborilmaydi ('SCREEN_TIME').
typedef UnlockRequestFlow = Future<void> Function({String? packageName});

final unlockRequestFlowProvider = Provider<UnlockRequestFlow>((ref) {
  final repo = ref.watch(backendUnlockRequestRepositoryProvider);

  return ({String? packageName}) async {
    // Modal faqat splash va PIN qulfi o'tgach, yangi sahifa chizilgan
    // navigatorda ochiladi — aks holda splash'ning go()'si uni yopib, so'rov
    // jimgina yo'qolardi. Shu paytgacha so'rov shu yerda kutib turadi.
    final ctx = await ref.read(shellReadyGateProvider).waitForContext();
    if (ctx == null || !ctx.mounted) return;

    // Bola qancha vaqt va nima uchun so'rashini kiritadi.
    final input = await UnlockRequestModal.show(ctx);
    if (input == null || !ctx.mounted) return; // bekor qildi

    final ok = await repo.createRequest(
      kind: packageName == null ? 'SCREEN_TIME' : 'APP',
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
  };
});

/// Native overlay/ogohlantirish → modal → backend so'rov ko'prigi (Android).
///
/// Bloklangan ilovada "Ruxsat so'rash" (yoki "vaqting tugayapti" notification)
/// Parvoz'ni ochadi; so'rov [unlockRequestFlowProvider] orqali yuboriladi.
final unlockRequestBridgeProvider = Provider<UnlockRequestBridge>((ref) {
  final flow = ref.watch(unlockRequestFlowProvider);
  return UnlockRequestBridge((packageName) => flow(packageName: packageName));
});

/// App ochilganda bir marta — native kutilayotgan unlock so'rovini tekshiradi.
/// `main.dart` ChildApp'da `ref.watch(unlockPendingCheckProvider)`.
///
/// Ko'prik darhol yaratiladi (ilova ochiq paytdagi `onUnlockRequested`
/// push'lari ham ushlanadi), lekin native paket faqat splash va PIN qulfi
/// o'tib, yangi sahifa chizilgach so'raladi: o'qish uni native tomonda
/// o'chiradi, shundan keyin modal shu zahoti tayyor navigatorda ochiladi.
final unlockPendingCheckProvider = FutureProvider<void>((ref) async {
  final bridge = ref.read(unlockRequestBridgeProvider);
  final gate = ref.read(shellReadyGateProvider);
  if (await gate.waitForContext() == null) return;
  await bridge.checkPending();
});
