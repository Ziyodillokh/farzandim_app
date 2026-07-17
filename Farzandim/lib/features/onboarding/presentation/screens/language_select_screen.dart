import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/onboarding/presentation/providers/language_picked_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/language_provider.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Birinchi ochilish — til tanlash ekrani (Parvoz dizayni).
///
/// Markazda Parvoz brendi, sarlavha va 3 ta shisha til kartasi (Parvoz dizayn-
/// tizimi). Tanlangan til ko'k bo'lib yonadi va check ko'rsatadi. Tilni
/// bossangiz ilova darhol o'sha tilga o'tadi, tanlov saqlanadi va welcome'ga
/// o'tiladi (`languagePickedProvider`).
class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  ConsumerState<LanguageSelectScreen> createState() =>
      _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen> {
  // Ikki marta bosishni va o'tish jarayonida qayta navigatsiyani bloklaydi.
  bool _navigating = false;

  Future<void> _select(AppLanguage lang) async {
    if (_navigating) return;
    setState(() => _navigating = true);

    // Tilni darhol almashtiramiz — sarlavha/izoh jonli yangilanadi va
    // bosilgan karta tanlangan holatga o'tadi (jonli ko'rinish).
    await context.setLocale(lang.locale);

    // Tanlov animatsiyasi ko'rinib ulgurishi uchun qisqa pauza.
    await Future<void>.delayed(const Duration(milliseconds: 280));

    await ref.read(languagePickedProvider.notifier).markPicked();
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final current = AppLanguage.fromCode(context.locale.languageCode);

    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: Stack(
        children: [
          // Tepa markazdagi yumshoq ko'k yog'du.
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: Center(child: ParvozTopGlow()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const ParvozBrandLogo(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'language.selectTitle'.tr(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.unbounded(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.72,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'language.selectSubtitle'.tr(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 24),
                            for (final lang in AppLanguage.values) ...[
                              _LangRow(
                                lang: lang,
                                selected: lang == current,
                                onTap: () => _select(lang),
                              ),
                              if (lang != AppLanguage.values.last)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'onboarding.version'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bitta til varianti — Parvoz shisha kartasi (tanlangani ko'k + check).
class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: selected,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              child: SvgPicture.asset(_flagAsset(lang), width: 24, height: 24),
            ),
            const SizedBox(width: 12),
            Text(
              lang.label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              const Icon(
                SolarIconsBold.checkCircle,
                size: 20,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Har til uchun bayroq SVG asset yo'li.
String _flagAsset(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.uz:
      return 'assets/icons/flag_uz.svg';
    case AppLanguage.ru:
      return 'assets/icons/flag_ru.svg';
    case AppLanguage.en:
      return 'assets/icons/flag_gb.svg';
  }
}
