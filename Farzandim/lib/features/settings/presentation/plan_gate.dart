// Tarif (entitlement) gate yordamchilari — qulflangan funksiya / bola-limit
// bosilganda "yuksalting" oynasi + kerakli tarifga o'tish.
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/settings/data/entitlement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _dialogOpen = false;

/// Tarif "yuksalting" oynasi — qulflangan funksiya/limitda ko'rsatiladi.
/// [tier] — tavsiya (standard/premium); [message] — sabab (ixtiyoriy).
/// "Tariflarni ko'rish" bosilsa `/premium` sahifasiga o'tadi.
Future<void> showUpgradeDialog(
  BuildContext context,
  WidgetRef ref, {
  String? tier,
  String? message,
}) async {
  if (_dialogOpen) return;
  _dialogOpen = true;
  final t = (tier == null || tier.isEmpty) ? 'premium' : tier;
  final tierName = t[0].toUpperCase() + t.substring(1);
  try {
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('plans.recommendTier'.tr(namedArgs: {'tier': tierName})),
        content: (message != null && message.isNotEmpty) ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text('plans.later'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dCtx).pop();
              ref.read(routerProvider).push(AppRoutes.premium);
            },
            child: Text('plans.viewPlans'.tr()),
          ),
        ],
      ),
    );
  } finally {
    _dialogOpen = false;
  }
}

/// "Bola qo'shish"ni tarif bo'yicha gate qiladi: limit yetgan bo'lsa BOSISHDA
/// darhol "Premium" oynasini ko'rsatadi (formani ochmasdan); aks holda
/// bola qo'shish ekraniga o'tadi.
void guardAddChild(BuildContext context, WidgetRef ref) {
  final ent = ref.read(entitlementProvider).valueOrNull ?? Entitlement.free;
  final count = ref.read(childrenListProvider).length;
  if (count >= ent.maxChildren) {
    showUpgradeDialog(
      context,
      ref,
      tier: 'premium',
      message: 'plans.childLimitMsg'.tr(
        namedArgs: {'max': ent.maxChildren.toString()},
      ),
    );
    return;
  }
  ref.read(routerProvider).push(AppRoutes.addChild);
}
