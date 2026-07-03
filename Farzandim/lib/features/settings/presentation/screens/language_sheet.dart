// "Ilova tili" — Tizim so'zlamalari "Ilova tili" qatoridan ochiladigan Parvoz
// bottom sheet. 3 til (O'zbek/Rus/English) kartalari + tanlangani checkmark;
// "Saqlash" bosilganda easy_localization locale o'zgaradi (SharedPreferences'ga
// avtomatik saqlanadi) va ilova yangi tilda qayta quriladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0F141A);
const _card = Color(0x0AFFFFFF); // oq 4% (tanlanmagan)
const _cardSel = Color(0x14FFFFFF); // oq 8% (tanlangan)
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _blue = Color(0xFF216BFF);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.4,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

/// Til kodi + i18n nom kaliti.
class _Lang {
  const _Lang(this.code, this.nameKey);
  final String code;
  final String nameKey;
}

const _langs = <_Lang>[
  _Lang('uz', 'languageSheet.uz'),
  _Lang('ru', 'languageSheet.ru'),
  _Lang('en', 'languageSheet.en'),
];

/// Ilova tili varag'ini ochadi.
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late String _selected = context.locale.languageCode;

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.setLocale(Locale(_selected));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'languageSheet.title'.tr(),
                  textAlign: TextAlign.center,
                  style: _unb(17, w: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                for (final l in _langs) ...[
                  _Option(
                    label: l.nameKey.tr(),
                    selected: _selected == l.code,
                    onTap: () => setState(() => _selected = l.code),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                ParvozPrimaryButton(
                  label: 'common.save'.tr(),
                  onPressed: _save,
                  showArrow: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Til kartasi — nom + tanlangani uchun checkmark.
class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? _cardSel : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _blue.withValues(alpha: 0.55) : _cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _unb(
                  16,
                  w: selected ? FontWeight.w700 : FontWeight.w500,
                  ls: -0.2,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}
