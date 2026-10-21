// ─────────────────────────────────────────────────────────────────────
// school_sheet — maktab varaqlarining umumiy qismlari
// ─────────────────────────────────────────────────────────────────────
//
// Varaq skeleti (tortish belgisi, sarlavha, aylantiriladigan mazmun,
// klaviatura ustida), tanlov qatori, izoh qutisi, xato qatori va matnli
// tugma. Forma maydonlari — `school_form_fields.dart`. Uslub moslash
// varag'i bilan bir xil.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _sheetBg = Color(0xFF0B1016);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x8CFFFFFF); // oq 55%
const _optionBg = Color(0x0FFFFFFF); // oq 6%
const _optionBorder = Color(0x1AFFFFFF); // oq 10%
const _chipBg = Color(0xFF1B2128);
const _danger = Color(0xFFFF5A5D);

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.4,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Maktab varag'ini ochadi (qorong'i fon, tepasi yumaloq, klaviatura
/// ochilsa mazmun ko'tariladi).
Future<T?> showSchoolSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: builder,
  );
}

/// Tortish belgisi.
class SchoolSheetHandle extends StatelessWidget {
  const SchoolSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

/// Varaq skeleti: tortish belgisi, sarlavha, izoh va mazmun. Mazmun uzun
/// bo'lsa yoki klaviatura ochilsa aylantiriladi.
class SchoolSheetFrame extends StatelessWidget {
  const SchoolSheetFrame({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: ColoredBox(
          color: _sheetBg,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SchoolSheetHandle(),
                  const SizedBox(height: 16),
                  Text(title, textAlign: TextAlign.center, style: _unb(18)),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: _pop(13, c: _dim),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tanlov qatori (radio): ikon + nom (+ izoh) + belgi.
class SchoolChoiceTile extends StatelessWidget {
  const SchoolChoiceTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _blue.withValues(alpha: 0.14) : _optionBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _blue : _optionBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _chipBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(15, w: FontWeight.w500),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(12.5, c: _dim),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _blue : Colors.transparent,
        border: Border.all(
          color: selected ? _blue : Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// Izoh qutisi (masalan "so'rov faqat bugun uchun").
class SchoolNote extends StatelessWidget {
  const SchoolNote({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _optionBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _optionBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: _pop(13.5, c: _dim)),
          ),
        ],
      ),
    );
  }
}

/// Forma xatosi (qizil ikon + matn).
class SchoolInlineError extends StatelessWidget {
  const SchoolInlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SolarIconsBold.dangerCircle, size: 18, color: _danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: _pop(13, c: _danger)),
          ),
        ],
      ),
    );
  }
}

/// Asosiy tugma ostidagi matnli tugma ("Bekor qilish", "Tushunarli").
class SchoolTextButton extends StatelessWidget {
  const SchoolTextButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: _pop(
                15,
                w: FontWeight.w600,
                c: Colors.white.withValues(alpha: onTap == null ? 0.35 : 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
