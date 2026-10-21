// ─────────────────────────────────────────────────────────────────────
// school_form_fields — maktab formalarining maydonlari
// ─────────────────────────────────────────────────────────────────────
//
// Shisha matn maydoni (yorliq + UTF-16 hisoblagich — backend bilan bir xil;
// bir yoki ko'p qatorli), bosiladigan tanlash maydoni va 24 soatlik vaqt
// tanlagich. Uslub `ParvozTextField` bilan bir xil: shisha fon, fokusda
// ko'k hoshiya, ko'k kursor.

import 'package:farzandim/features/school/presentation/school_form_rules.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _sheetBg = Color(0xFF0B1016);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x8CFFFFFF); // oq 55%
const _hint = Color(0x59FFFFFF); // oq 35%
const _chipBg = Color(0xFF1B2128);
const _amber = Color(0xFFFBBF24);

/// Hisoblagich shu ulushdan oshsa sariq bo'ladi.
const double _counterWarnRatio = 0.9;

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// 24 soatlik vaqt tanlagich (Parvoz: qorong'i fon, ko'k aksent).
Future<TimeOfDay?> showSchoolTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  required String helpText,
}) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    helpText: helpText,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: Theme(
        data: _pickerTheme(Theme.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

ThemeData _pickerTheme(ThemeData base) => base.copyWith(
  colorScheme: const ColorScheme.dark(
    primary: _blue,
    surface: _sheetBg,
    surfaceContainerHighest: _chipBg,
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  timePickerTheme: TimePickerThemeData(
    backgroundColor: _sheetBg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: Colors.white),
  ),
);

/// Forma maydoni yorlig'i ("Sabab", "O'quvchi").
class SchoolFieldLabel extends StatelessWidget {
  const SchoolFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: _pop(14));
}

/// Shisha matn maydoni: yorliq + "12/160" hisoblagich (UTF-16, backend
/// bilan bir xil) + bir yoki ko'p qatorli kiritish.
class SchoolTextArea extends StatefulWidget {
  const SchoolTextArea({
    required this.label,
    required this.controller,
    required this.maxLength,
    this.hint,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Eng ko'p UTF-16 birligi (backend `max`).
  final int maxLength;
  final String? hint;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<SchoolTextArea> createState() => _SchoolTextAreaState();
}

class _SchoolTextAreaState extends State<SchoolTextArea> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SchoolFieldLabel(widget.label)),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) {
                final length = value.text.length;
                final warn = length >= widget.maxLength * _counterWarnRatio;
                return Text(
                  '$length/${widget.maxLength}',
                  style: _pop(12, c: warn ? _amber : _dim),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(multiline ? 22 : 999),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: focused ? _blue : Colors.white.withValues(alpha: 0.12),
              width: focused ? 1.5 : 1.2,
            ),
          ),
          child: TextSelectionTheme(
            data: const TextSelectionThemeData(
              cursorColor: _blue,
              selectionHandleColor: _blue,
              selectionColor: Color(0x5C216BFF),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              minLines: multiline ? 2 : 1,
              maxLines: widget.maxLines,
              keyboardType: multiline
                  ? TextInputType.multiline
                  : TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [SchoolLengthLimiter(widget.maxLength)],
              onChanged: widget.onChanged,
              cursorColor: _blue,
              style: _pop(15),
              decoration: InputDecoration(
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: _pop(15, c: _hint),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: multiline ? 14 : 17,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bosiladigan maydon (vaqt va h.k.): ikon + qiymat yoki placeholder.
class SchoolPickerField extends StatelessWidget {
  const SchoolPickerField({
    required this.label,
    required this.icon,
    required this.placeholder,
    required this.onTap,
    this.value,
    super.key,
  });

  final String label;
  final IconData icon;
  final String placeholder;
  final VoidCallback? onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchoolFieldLabel(label),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: label,
          value: value ?? placeholder,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: value == null
                          ? _pop(15, c: _hint)
                          : _pop(16, w: FontWeight.w600),
                    ),
                  ),
                  const Icon(
                    SolarIconsOutline.altArrowDown,
                    size: 18,
                    color: _dim,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
