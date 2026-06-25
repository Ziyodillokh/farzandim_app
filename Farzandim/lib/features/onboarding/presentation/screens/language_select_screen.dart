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

/// Bitta til varianti — premium frosted glass karta.
///
/// Shisha effekti qatlamlardan tuziladi (fon juda qora, shu sabab oddiy
/// shaffoflik bilinmaydi): yarim-shaffof yo'naltirilgan fill (yorug' yuqori-
/// chap, light -45°) + nozik ko'k tint + sheen + tepa specular chiziq +
/// yorqin rim + chuqurlik soyasi. Tanlangani ko'k gradient + ko'k glow.
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
        // Chuqurlik soyasi (clip'dan tashqarida) — shisha fonidan ko'tariladi.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
            if (selected)
              BoxShadow(
                color: _kBlue.withValues(alpha: 0.5),
                blurRadius: 28,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // Haqiqiy frost — ortida nimadir bo'lsa (yog'du) xiralashadi.
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                // Yo'naltirilgan fill — yorug' yuqori-chap, to'q past-o'ng
                // (light -45°, konveks chuqurlik).
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kBlueLight, _kBlue],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.035),
                        ],
                      ),
              ),
              child: Stack(
                children: [
                  // Nozik ko'k ambient tint (faqat shisha kartalarda).
                  if (!selected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: _kGlow.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  // Sheen — yuqori-chapdan yumshoq yorug'lik.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.center,
                            colors: [
                              Colors.white.withValues(
                                alpha: selected ? 0.22 : 0.14,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tepa specular chiziq (~1.5px) — "haqiqiy shisha" eng kuchli
                  // belgisi (yuqoridan tushgan yorug'lik).
                  Positioned(
                    top: 0,
                    left: 18,
                    right: 18,
                    child: IgnorePointer(
                      child: SizedBox(
                        height: 1.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(
                                  alpha: selected ? 0.6 : 0.55,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Yorqin rim — refraksiya chetini taqlid qiladi.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: selected ? 0.32 : 0.22,
                            ),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mazmun — bayroq + nom + (tanlangan) check.
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5)),
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
