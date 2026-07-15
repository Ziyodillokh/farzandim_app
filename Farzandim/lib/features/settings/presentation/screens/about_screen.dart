import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── Yangi dizayn tokenlari (Manzillar/Joylashuv bilan bir xil) ───
const Color _bg = Color(0xFF0B0B10); // qora fon
const Color _cardBg = Color(0xFF1A1B22); // qoramtir karta
const Color _cardBorder = Color(0x14FFFFFF); // oq ~8% chegara
const Color _dim = Color(0x99FFFFFF); // oq 60% ikkilamchi matn
const Color _glassBtn = Color(0xE6121C2E); // top-bar tugma foni

/// Ilova haqida ekrani — logo, versiya, qisqa tavsif, linklar.
///
/// REDIZAYN: eski gradient fon o'rniga yangi qora-glass dizayn. Logo endi
/// glass ramka ichida, orqasidan yumshoq lime (brend rangi) nur bilan.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.sm,
                  AppDimensions.md,
                  AppDimensions.lg,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppDimensions.md),

                    // ── LOGO (glass ramka + lime nur) ──
                    const _LogoBadge(),
                    const SizedBox(height: AppDimensions.lg),

                    // Ilova nomi.
                    Text(
                      'about.appName'.tr(),
                      style: AppTextStyles.headlineXL.copyWith(
                        fontSize: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),

                    // Versiya — kichik glass "pill" chip.
                    const _VersionChip(),
                    const SizedBox(height: AppDimensions.xl),

                    // ── Tavsif kartasi ──
                    const _DescriptionCard(),
                    const SizedBox(height: AppDimensions.lg),

                    // ── Huquqiy linklar ──
                    _LinkTile(
                      icon: SolarIconsBold.documentText,
                      title: 'about.termsLink'.tr(),
                      onTap: () => context.push(AppRoutes.legalTermsOfService),
                    ),
                    const SizedBox(height: AppDimensions.sm + 2),
                    _LinkTile(
                      icon: SolarIconsBold.shieldWarning,
                      title: 'about.privacyLink'.tr(),
                      onTap: () => context.push(AppRoutes.legalPrivacyPolicy),
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // ── Footer ──
                    Text(
                      'about.madeWithLove'.tr(),
                      style: AppTextStyles.label.copyWith(color: _dim),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Boshqa yangi ekranlar bilan bir xil: tepadan pastroq (md + 44).
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md + 44,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: SolarIconsOutline.arrowLeft,
            onTap: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'about.headerTitle'.tr(),
                style: AppTextStyles.headlineL.copyWith(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // O'ng tomon bo'sh — sarlavha markazda tursin (simmetriya).
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}

/// Top-bar yumaloq-kvadrat shisha tugmasi (yangi dizayn uslubi).
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _glassBtn,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: Icon(icon, size: 22, color: Colors.white)),
        ),
      ),
    );
  }
}

// ════════════════════════ LOGO BADGE ════════════════════════

/// Logo — glass kvadrat ramka, orqasidan yumshoq lime (brend) nur.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          // Brend rangida yumshoq nur (glow) — logoni "jonlantiradi".
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22),
            blurRadius: 36,
            spreadRadius: -8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: SvgPicture.asset('assets/icons/parvoz_logo_mark.svg'),
    );
  }
}

// ════════════════════════ VERSION CHIP ════════════════════════

class _VersionChip extends StatelessWidget {
  const _VersionChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        'about.version'.tr(),
        style: AppTextStyles.bodyS.copyWith(
          color: _dim,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ════════════════════════ TAVSIF KARTASI ════════════════════════

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'about.description1'.tr(),
            style: AppTextStyles.bodyS.copyWith(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'about.description2'.tr(),
            style: AppTextStyles.bodyS.copyWith(
              color: _dim,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ LINK TILE ════════════════════════

/// Huquqiy hujjat linki — accent ikon-chip + sarlavha + o'q.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Lime (brend) rangli yumshoq ikon-chip.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 21, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyM.copyWith(color: Colors.white),
                ),
              ),
              const Icon(
                SolarIconsOutline.altArrowRight,
                size: 20,
                color: _dim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
