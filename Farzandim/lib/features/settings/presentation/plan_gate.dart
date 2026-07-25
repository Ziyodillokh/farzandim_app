// Tarif (entitlement) gate yordamchilari — qulflangan funksiya / bola-limit
// bosilganda "yuksalting" oynasi + kerakli tarifga o'tish; hamda Standart
// 1-haftalik demo (trial) xabarlari (xush kelibsiz / tugadi) va banneri.
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

// Olov rang — trial (demo) banneri uchun: "vaqt tugab boryapti" hissi.
const Color _kFlame = Color(0xFFF15A0C);
const Color _kFlameLight = Color(0xFFFFA637);

bool _dialogOpen = false;

/// Tarif "yuksalting" oynasi — qulflangan funksiya/limitda ko'rsatiladi.
/// Shisha (frosted) karta: "Tariflarni ko'rish" (premium) + "Keyinroq".
/// [tier] — tavsiya (standard/premium); [message] — sabab (ixtiyoriy).
Future<void> showUpgradeDialog(
  BuildContext context,
  WidgetRef ref, {
  String? tier,
  String? message,
}) async {
  final t = (tier == null || tier.isEmpty) ? 'premium' : tier;
  final tierName = t[0].toUpperCase() + t.substring(1);
  await _showGlassDialog(
    context,
    title: 'plans.recommendTier'.tr(namedArgs: {'tier': tierName}),
    message: message,
    primaryLabel: 'plans.viewPlans'.tr(),
    onPrimary: (dCtx) {
      Navigator.of(dCtx).pop();
      ref.read(routerProvider).push(AppRoutes.premium);
    },
    secondaryLabel: 'plans.later'.tr(),
  );
}

/// Trial boshlanganda (1-kirish) — "sovg'a" xush kelibsiz oynasi.
Future<void> showTrialWelcomeDialog(BuildContext context, WidgetRef ref) async {
  await _showGlassDialog(
    context,
    icon: Icons.card_giftcard_rounded,
    title: 'trial.welcomeTitle'.tr(),
    message: 'trial.welcomeBody'.tr(),
    primaryLabel: 'trial.welcomeCta'.tr(),
    onPrimary: (dCtx) => Navigator.of(dCtx).pop(),
  );
}

/// Trial tugagach (free'ga o'tilganda) — bir martalik xabar + tariflar.
Future<void> showTrialEndedDialog(BuildContext context, WidgetRef ref) async {
  await _showGlassDialog(
    context,
    title: 'trial.endedTitle'.tr(),
    message: 'trial.endedBody'.tr(),
    primaryLabel: 'trial.endedCta'.tr(),
    onPrimary: (dCtx) {
      Navigator.of(dCtx).pop();
      ref.read(routerProvider).push(AppRoutes.premium);
    },
    secondaryLabel: 'trial.later'.tr(),
  );
}

/// Umumiy shisha (frosted) oyna — bitta joyda (re-entrancy latch bilan).
Future<void> _showGlassDialog(
  BuildContext context, {
  required String title,
  required String primaryLabel,
  required void Function(BuildContext dCtx) onPrimary,
  String? message,
  String? secondaryLabel,
  IconData icon = Icons.workspace_premium_rounded,
}) async {
  if (_dialogOpen) return;
  _dialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dCtx) => _GlassDialog(
        icon: icon,
        title: title,
        message: message,
        primaryLabel: primaryLabel,
        onPrimary: () => onPrimary(dCtx),
        secondaryLabel: secondaryLabel,
        onSecondary: () => Navigator.of(dCtx).pop(),
      ),
    );
  } finally {
    _dialogOpen = false;
  }
}

/// Shisha (frosted) oyna — ort fon xiralashadi. Ikon + sarlavha + matn +
/// premium tugma (+ ixtiyoriy secondary).
class _GlassDialog extends StatelessWidget {
  const _GlassDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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
                  // Belgi — ko'k halqa ichida.
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBlue.withValues(alpha: 0.5)),
                    ),
                    child: Icon(icon, color: _kBlueLight, size: 28),
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
                  _PremiumButton(label: primaryLabel, onTap: onPrimary),
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: 8),
                    _SecondaryButton(
                      label: secondaryLabel!,
                      onTap: onSecondary ?? () {},
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium tugma — ko'k fon + oq matn.
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
  final ent = ref.read(entitlementProvider).valueOrNull;
  final count = ref.read(childrenListProvider).length;
  // Tarif ANIQ bo'lgandagina limitni tekshiramiz (fail-OPEN: aniqlanmagan
  // bo'lsa o'tkazamiz, backend limitni baribir enforce qiladi).
  if (ent != null && count >= ent.maxChildren) {
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

/// Faqat PULLIK tarif (standard/premium) funksiyasi: free bo'lsa BOSISHDA
/// "yuksalting" oynasi (Standart tavsiya) chiqadi; aks holda [onAllowed]
/// bajariladi. Lokatsiya, ilova bloklash, rejim/jadval kabi funksiyalar uchun.
void guardPaid(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onAllowed,
  String? message,
}) {
  final ent = ref.read(entitlementProvider).valueOrNull;
  // Faqat ANIQ `free` bo'lsa bloklaymiz. Aniqlanmagan (yuklanmoqda/xato) —
  // o'tkazamiz (fail-OPEN): backend guard baribir himoyalaydi, pullik
  // foydalanuvchini tarmoq blip'ida bezovta qilmaymiz.
  if (ent == null || !ent.isFree) {
    onAllowed();
    return;
  }
  showUpgradeDialog(
    context,
    ref,
    tier: 'standard',
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

/// Ilovaga kirganda trial xabarlarini ko'rsatadi (bir martadan):
///   • Trial FAOL bo'lsa — "sovg'a" xush kelibsiz oynasi (+ tugash sanasini
///     eslab qoladi).
///   • Trial endigina TUGAGAN (free'ga tushgan) bo'lsa — "tugadi" xabari.
/// Bu fon-popup EMAS — ataylab, bir martalik va foydalanuvchiga tushuntiruvchi.
Future<void> maybeShowTrialNotice(BuildContext context, WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final Entitlement ent;
  try {
    ent = await ref.read(entitlementProvider.future);
  } catch (_) {
    return; // tarif yuklanmadi — trial xabarini jimgina o'tkazamiz
  }
  if (!context.mounted) return;

  if (ent.isTrial) {
    // Trial faol — tugash sanasini saqlab qo'yamiz (keyin "tugadi" ni bilish
    // uchun) va bir marta xush kelibsiz oynasini ko'rsatamiz.
    final endIso = ent.trialEndsAt?.toIso8601String();
    if (endIso != null) await prefs.setString('trial_ends_at', endIso);
    if (prefs.getBool('trial_welcome_seen') ?? false) return;
    await prefs.setBool('trial_welcome_seen', true);
    if (!context.mounted) return;
    await showTrialWelcomeDialog(context, ref);
    return;
  }

  // Trial emas. Pullik foydalanuvchini bezovta qilmaymiz.
  if (ent.tier != 'free') return;
  // Avval trial bo'lgan va endi muddati o'tgan bo'lsa — bir martalik "tugadi".
  final storedIso = prefs.getString('trial_ends_at');
  if (storedIso == null) return; // hech qachon trial bo'lmagan
  if (prefs.getBool('trial_ended_seen') ?? false) return;
  final end = DateTime.tryParse(storedIso);
  if (end == null || DateTime.now().isBefore(end)) return; // hali tugamagan
  await prefs.setBool('trial_ended_seen', true);
  if (!context.mounted) return;
  await showTrialEndedDialog(context, ref);
}

/// Dashboard uchun trial banneri — "Standart demo — X kun qoldi" + "Saqlab
/// qolish". Faqat trial aktiv bo'lsa ko'rinadi (aks holda bo'sh joy).
class TrialBanner extends ConsumerWidget {
  /// `TrialBanner` konstruktor.
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementProvider).valueOrNull;
    if (ent == null || !ent.isTrial) return const SizedBox.shrink();
    final days = ent.trialDaysLeft;
    return GestureDetector(
      onTap: () => ref.read(routerProvider).push(AppRoutes.premium),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [_kFlame, _kFlameLight],
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'trial.daysLeft'.tr(namedArgs: {'days': days.toString()}),
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'trial.keep'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _kFlame,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
