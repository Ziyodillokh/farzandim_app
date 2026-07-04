// "Tizim so'zlamalari" — Parvoz dizayn. Tepada orqa tugma + sarlavha,
// so'ng premium tarif banneri (Batafsil → Parvoz Premium sahifasi) va 6 ta
// sozlama qatori: Akkount, Faol sessiyalar, Bildirishnomalar, Ilova tili,
// Qo'llab quvvatlash, Biz haqimizda.
//
// Chiqish / hisobni o'chirish "Akkount" (profil) sahifasiga ko'chirildi.

import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/profile/presentation/screens/profile_screen.dart';
import 'package:farzandim/features/settings/presentation/providers/language_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/sessions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x99FFFFFF); // oq 60%
const _glass = Color(0x1AFFFFFF); // oq 10% (Batafsil)

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.4,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Tizim so'zlamalari bosh ekrani.
class SettingsScreen extends ConsumerWidget {
  /// `SettingsScreen` konstruktor.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionCount = ref
        .watch(sessionsProvider)
        .maybeWhen(data: (list) => list.length, orElse: () => 0);
    final langLabel = AppLanguage.fromCode(context.locale.languageCode).label;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: Column(
                  children: [
                    _PremiumBanner(
                      onTap: () => context.push(AppRoutes.premium),
                    ),
                    const SizedBox(height: 24),
                    _SettingRow(
                      icon: SolarIconsBold.userCircle,
                      title: 'settings.rows.account.title'.tr(),
                      subtitle: 'settings.rows.account.subtitle'.tr(),
                      onTap: () => showAccountSheet(context),
                    ),
                    const SizedBox(height: 4),
                    _SettingRow(
                      icon: SolarIconsBold.devices,
                      title: 'settings.rows.sessions.title'.tr(),
                      subtitle: 'settings.rows.sessions.subtitle'.tr(
                        namedArgs: {'count': '$sessionCount'},
                      ),
                      onTap: () => context.push(AppRoutes.settingsSessions),
                    ),
                    const SizedBox(height: 4),
                    _SettingRow(
                      icon: SolarIconsBold.bellBing,
                      title: 'settings.rows.notifications.title'.tr(),
                      subtitle: 'settings.rows.notifications.subtitle'.tr(),
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                    const SizedBox(height: 4),
                    _SettingRow(
                      icon: SolarIconsBold.global,
                      title: 'settings.rows.language.title'.tr(),
                      subtitle: langLabel,
                      onTap: () => _showLanguageDialog(context, ref),
                    ),
                    const SizedBox(height: 4),
                    _SettingRow(
                      icon: SolarIconsBold.handHeart,
                      title: 'settings.rows.support.title'.tr(),
                      subtitle: 'settings.rows.support.subtitle'.tr(),
                      onTap: () => context.push(AppRoutes.support),
                    ),
                    const SizedBox(height: 4),
                    _SettingRow(
                      icon: SolarIconsBold.smileCircle,
                      title: 'settings.rows.about.title'.tr(),
                      subtitle: 'settings.rows.about.subtitle'.tr(),
                      onTap: () => context.push(AppRoutes.settingsAbout),
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

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _cardBorder),
        ),
        title: Text('settings.language.dialogTitle'.tr(), style: _unb(17)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLanguage.values)
              _LanguageOption(
                language: lang,
                isSelected:
                    lang == AppLanguage.fromCode(context.locale.languageCode),
                onTap: () async {
                  await context.setLocale(lang.locale);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Sarlavha (orqa + markazlashgan matn) ════════════
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _SquareButton(icon: SolarIconsOutline.arrowLeft, onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                'settings.systemTitle'.tr(),
                style: _unb(20, w: FontWeight.w500, ls: -0.6),
              ),
            ),
          ),
          // O'ng tomonda ko'rinmas muvozanat (sarlavha markazda tursin).
          const SizedBox(width: 56, height: 56),
        ],
      ),
    );
  }
}

/// 56x56 kvadrat tugma (orqaga) — Figma: #1A1F23 + oq rim + radius 16.
class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }
}

// ════════════ Premium banner ════════════
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 204,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Stack(
        children: [
          // Ichki xira rangli porlash (ko'k→siyan→binafsha aurora).
          Positioned(
            left: -30,
            top: -40,
            width: 280,
            height: 210,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      Color(0xFF0055FF),
                      Color(0xFF3CF9FF),
                      Color(0xFF6A00FF),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          // Ko'k radial tint (tepa-chapda, 40%).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.55, -0.9),
                  radius: 1.1,
                  colors: [Color(0x66508AFF), Colors.transparent],
                  stops: [0, 0.75],
                ),
              ),
            ),
          ),
          // Mazmun.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [_BannerLogo(), Spacer(), _PremiumPill()]),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings.premiumBanner.description'.tr(),
                      style: _pop(14, c: const Color(0xFFF9F9F9)),
                    ),
                    const SizedBox(height: 10),
                    _BatafsilButton(onTap: onTap),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerLogo extends StatelessWidget {
  const _BannerLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/parvoz_logo_mark.svg',
          width: 34,
          height: 34,
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parvoz', style: _unb(16, ls: -0.3)),
            const SizedBox(height: 2),
            Text('Parents', style: _pop(11, c: _dim)),
          ],
        ),
      ],
    );
  }
}

/// "PREMIUM" pill — ko'k→indigo→binafsha gradient.
class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: const LinearGradient(
          begin: Alignment(-1, -0.4),
          end: Alignment(1, 0.4),
          colors: [Color(0xFF21AEFF), Color(0xFF3F3FCC), Color(0xFF5D1499)],
          stops: [0.01, 0.46, 0.93],
        ),
      ),
      child: Text('PREMIUM', style: _unb(13, ls: -0.39)),
    );
  }
}

/// "Batafsil" — shaffof shisha pill tugma.
class _BatafsilButton extends StatelessWidget {
  const _BatafsilButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'settings.premiumBanner.details'.tr(),
          style: _pop(16, w: FontWeight.w500),
        ),
      ),
    );
  }
}

// ════════════ Sozlama qatori ════════════
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(16, ls: -0.48),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(14, c: _dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              SolarIconsOutline.altArrowRight,
              size: 22,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Til tanlash qatori (dialog ichida) ════════════
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(child: Text(language.label, style: _pop(15))),
            if (isSelected)
              const Icon(SolarIconsBold.checkCircle, color: _blue, size: 20),
          ],
        ),
      ),
    );
  }
}
