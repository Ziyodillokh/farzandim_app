// Akkauntga o'tish (A10 va A02 «Kalit bilan kirish»): qurilma egasi —
// darhol (qurilma uniki); mehmon akkaunt — qurilma kaliti bilan (barmoq izi /
// yuz) yoki parol bilan (A02, login oldindan to'ldirilgan). Kalit rad etilsa,
// bekor qilinsa yoki saqlangan sessiya bo'lmasa — parol so'raladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Future<void> switchToAccount(
  BuildContext context,
  WidgetRef ref,
  DeviceAccount account,
) async {
  final registry = ref.read(accountRegistryProvider);
  if (account.owner) {
    final wasGuest = registry.activeGuest != null;
    await registry.activate(account.childId);
    // Mehmondan egaga — ildiz qayta quriladi; aks holda shu yerda davom.
    if (!wasGuest && context.mounted) context.go('/splash');
    return;
  }
  final hasSession = await guestTokenStorage(account.childId).hasValidSession();
  if (hasSession && account.deviceKey) {
    final ok = await ref
        .read(deviceKeyProvider)
        .confirm(
          'g5.kirish.accounts.keyReason'.tr(namedArgs: {'name': account.name}),
        );
    if (ok) {
      if (registry.activeGuest?.childId == account.childId) {
        if (context.mounted) context.go('/splash');
        return;
      }
      await registry.activate(account.childId);
      return;
    }
  }
  if (!context.mounted) return;
  context.push(
    Uri(
      path: GrowthV5Routes.kirishLogin,
      queryParameters: {'login': ?account.login},
    ).toString(),
  );
}
