// ─────────────────────────────────────────────────────────────────────
// LanguageSelectScreen — bola ilovani birinchi marta ochganida til tanlaydi
// (Parvoz dizayni — ota-ona ilovasidagi til sahifasi bilan bir xil, ko'k
// shisha). Logo "Parvoz" (Parents yozuvisiz). Til tanlangach darhol o'sha
// tilga o'tadi, tanlov saqlanadi va /splash keyingi qadamga yo'naltiradi.
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences kaliti — til bir marta tanlangach qayta so'ralmaydi.
const String kLanguagePickedKey = 'language_picked_v1';

// ════════════ Parvoz tokenlar (lokal, ko'k) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _blueLight = Color(0xFF3C82FF);
const _dim = Color(0x99FFFFFF);

const _languages = <(Locale, String, String)>[
  (Locale('uz'), "O'zbekcha", 'assets/icons/flag_uz.svg'),
  (Locale('ru'), 'Русский', 'assets/icons/flag_ru.svg'),
  (Locale('en'), 'English', 'assets/icons/flag_gb.svg'),
];

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  bool _navigating = false;

  Future<void> _select(Locale locale) async {
    if (_navigating) return;
    setState(() => _navigating = true);

    // Tilni darhol almashtiramiz — sarlavha/izoh va tanlangan karta jonli
    // yangilanadi.
    await context.setLocale(locale);
    // Tanlov ko'rinib ulgurishi uchun qisqa pauza.
    await Future<void>.delayed(const Duration(milliseconds: 280));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLanguagePickedKey, true);
    if (mounted) context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _TopGlow())),
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
                                color: _dim,
                              ),
                            ),
                            const SizedBox(height: 24),
                            for (final lang in _languages) ...[
                              _LangRow(
                                label: lang.$2,
                                flagAsset: lang.$3,
                                selected: lang.$1.languageCode == current,
                                onTap: () => _select(lang.$1),
                              ),
                              if (lang != _languages.last)
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

// ════════════ Brand: logo + "Parvoz" ════════════
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/parvoz_logo_mark.svg',
          width: 50,
          height: 50,
        ),
        const SizedBox(width: 13),
        Text(
          'Parvoz',
          style: GoogleFonts.unbounded(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ════════════ Yumshoq ko'k yog'du ════════════
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x73508AFF), Color(0x00508AFF)],
          stops: [0, 0.72],
        ),
      ),
    );
  }
}

// ════════════ Bitta til qatori — shisha (tanlangani ko'k + check) ════════════
class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.label,
    required this.flagAsset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String flagAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 60,
        decoration: selected ? _bluePill() : _glassPill(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              child: SvgPicture.asset(flagAsset, width: 24, height: 24),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_rounded, size: 20, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════ Shisha dekoratsiyalar ════════════
BoxDecoration _glassPill() => BoxDecoration(
  borderRadius: BorderRadius.circular(999),
  gradient: const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
  ),
  border: Border.all(color: const Color(0x1FFFFFFF), width: 1.2),
);

BoxDecoration _bluePill() => BoxDecoration(
  borderRadius: BorderRadius.circular(999),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_blueLight, _blue],
  ),
  border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
  boxShadow: [
    BoxShadow(
      color: _blue.withValues(alpha: 0.45),
      blurRadius: 26,
      spreadRadius: -2,
      offset: const Offset(0, 10),
    ),
  ],
);
