import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/onboarding/presentation/providers/language_picked_provider.dart';
import 'package:farzandim/features/settings/presentation/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Parvoz onboarding brendi (faqat shu ekran uchun lokal palitra) ───
// Yangi dizayn ilovaning teal "Deep Sea" temasidan farq qiladi: chuqur
// qora-ko'k fon + #216BFF ko'k aksent. Boshqa ekranlar bosqichma-bosqich
// shu dizaynga ko'chiriladi, shu sabab ranglar hozircha shu yerda.
const Color _kBg = Color(0xFF02060D);
const Color _kBlue = Color(0xFF216BFF);
const Color _kBlueLight = Color(0xFF3C82FF);
const Color _kGlow = Color(0xFF508AFF);

/// Birinchi ochilish — til tanlash ekrani (Parvoz dizayni).
///
/// Markazda Parvoz brendi, sarlavha va 3 ta "shisha" (frosted glass) til
/// kartasi. Tanlangan til ko'k bo'lib yonadi va check ko'rsatadi. Tilni
/// bossangiz ilova darhol o'sha tilga o'tadi, tanlov saqlanadi va
/// welcome'ga o'tiladi (`languagePickedProvider`).
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
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Tepa markazdagi yumshoq ko'k yog'du.
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: Center(child: _TopGlow()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const _BrandLogo(),
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
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Version - 1.0',
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

/// Tepadagi yumshoq ko'k radial yog'du (logo ortida).
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _kGlow.withValues(alpha: 0.45),
            const Color(0x00508AFF),
          ],
          stops: const [0, 0.72],
        ),
      ),
    );
  }
}

/// Parvoz brend belgisi — logo + "Parvoz / Parents" so'z belgisi.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/parvoz_logo_mark.svg',
          width: 44,
          height: 44,
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parvoz',
              style: GoogleFonts.unbounded(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.3,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Parents',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bitta til varianti — frosted glass karta. Tanlangani ko'k bo'lib yonadi
/// va o'ngida check ko'rsatiladi.
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
    const radius = BorderRadius.all(Radius.circular(999));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        // Ko'k yog'du faqat tanlangan kartada — clip'dan tashqarida turishi
        // uchun tashqi qatlamda.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // Haqiqiy "shisha" frost — ortidagi fon biroz xiralashadi.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_kBlueLight, _kBlue],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                    child: SvgPicture.asset(
                      _flagAsset(lang),
                      width: 24,
                      height: 24,
                    ),
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
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.white,
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
