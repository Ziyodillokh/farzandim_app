// Tarif (entitlement) gate yordamchilari — qulflangan funksiya / bola-limit
// bosilganda "yuksalting" oynasi + kerakli tarifga o'tish.
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/settings/data/entitlement.dart';
import 'package:farzandim/features/settings/data/repositories/backend_payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Brend ko'k — premium (paywall) ekrani bilan bir xil, modal shunga mos.
const Color _kBlue = Color(0xFF216BFF);
const Color _kBlueLight = Color(0xFF6FA0FF);

bool _dialogOpen = false;

/// Tarif "yuksalting" oynasi — qulflangan funksiya/limitda ko'rsatiladi.
/// Shisha (frosted) karta: "Keyinroq" (secondary) + "Tariflarni ko'rish"
/// (premium tugma). [tier] — tavsiya (standard/premium); [message] — sabab.
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dCtx) => _UpgradeDialog(
        title: 'plans.recommendTier'.tr(namedArgs: {'tier': tierName}),
        message: message,
        onView: () {
          Navigator.of(dCtx).pop();
          ref.read(routerProvider).push(AppRoutes.premium);
        },
        onLater: () => Navigator.of(dCtx).pop(),
      ),
    );
  } finally {
    _dialogOpen = false;
  }
}

/// Shisha "yuksalting" oynasi — ort fon xiralashadi (frosted glass).
class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog({
    required this.title,
    required this.message,
    required this.onView,
    required this.onLater,
  });

  final String title;
  final String? message;
  final VoidCallback onView;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // To'q shisha — matn tiniq o'qiladi, ort fon esa xiralashadi.
              color: const Color(0xFF0B1220).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium belgisi — ko'k halqa ichida.
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBlue.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: _kBlueLight,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: GoogleFonts.unbounded(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      message!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _PremiumButton(label: 'plans.viewPlans'.tr(), onTap: onView),
                  const SizedBox(height: 8),
                  _SecondaryButton(label: 'plans.later'.tr(), onTap: onLater),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium tugma — ko'k fon + oq matn ("Tariflarni ko'rish").
class _PremiumButton extends StatelessWidget {
  const _PremiumButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Ikkilamchi tugma — shaffof, xira matn ("Keyinroq").
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
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

/// Qulflangan funksiyani gate qiladi: tarifda [feature] bo'lsa [onAllowed]
/// bajariladi; bo'lmasa BOSISHDA darhol "yuksalting" oynasi chiqadi. Fon
/// so'rovlaridan emas — faqat foydalanuvchi bosgani uchun (client-side).
void guardFeature(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
  required VoidCallback onAllowed,
  String? tier,
  String? message,
}) {
  final ent = ref.read(entitlementProvider).valueOrNull ?? Entitlement.free;
  if (ent.has(feature)) {
    onAllowed();
    return;
  }
  showUpgradeDialog(
    context,
    ref,
    tier: tier ?? _minTierForFeature(ref, feature),
    message: message ?? 'plans.featureLockedMsg'.tr(),
  );
}

/// Berilgan funksiya bor ENG ARZON pullik tarif darajasi (yuklangan
/// planlardan). Topilmasa 'premium' — top tarif har doim hammasini o'z
/// ichiga oladi, shuning uchun xavfsiz tavsiya.
String _minTierForFeature(WidgetRef ref, String feature) {
  const rank = {'free': 0, 'basic': 1, 'standard': 2, 'premium': 3, 'vip': 4};
  final plans =
      ref.read(plansProvider).valueOrNull?.plans ?? const <PlanEntry>[];
  String? best;
  var bestRank = 1 << 30;
  for (final p in plans) {
    if (p.priceUzs <= 0 || !p.features.contains(feature)) continue;
    final r = rank[p.entitlementTier] ?? 5;
    if (r < bestRank) {
      bestRank = r;
      best = p.entitlementTier;
    }
  }
  return best ?? 'premium';
}

/// Ilovaga BIRINCHI kirganda (bir marta, faqat bepul tarifda) "yuksalting"
/// oynasini ko'rsatadi. Keyingi ochilishlarda takrorlanmaydi — flag saqlanadi.
/// Bu "o'zidan-o'zi chiqadigan" fon-popup EMAS; ataylab, bir martalik promo.
Future<void> maybeShowFirstLaunchPromo(
  BuildContext context,
  WidgetRef ref,
) async {
  const key = 'parvoz_upgrade_promo_seen';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(key) ?? false) return;
  // Tarif yuklanishini kutamiz (xato/tarmoqda `free` qaytadi).
  final ent = await ref.read(entitlementProvider.future);
  await prefs.setBool(key, true); // bir marta ko'rsatildi (yoki o'tkazildi)
  if (ent.tier != 'free') return; // pullik foydalanuvchi bezovta qilinmaydi
  if (!context.mounted) return;
  await showUpgradeDialog(
    context,
    ref,
    tier: 'premium',
    message: 'plans.firstLaunchPromo'.tr(),
  );
}
