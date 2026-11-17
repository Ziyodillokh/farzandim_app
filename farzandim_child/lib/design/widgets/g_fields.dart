// Kiritish elementlari: matn maydoni (`.inp`), kod kataklari (`.otp`).

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:farzandim_child/design/tokens.dart';
import 'package:farzandim_child/design/typography.dart';
import 'package:farzandim_child/design/widgets/g_buttons.dart';
import 'package:farzandim_child/design/widgets/g_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Maydon qobig'i: fon, chegara va tashqi fokus/xato halqasi.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.child,
    required this.focused,
    required this.error,
    this.padding = EdgeInsets.zero,
    this.minHeight = 54,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final bool focused;
  final bool error;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(GRadius.field);
    final border = error
        ? GColors.errorBorder
        : focused
        ? GColors.focusBorder
        : GColors.fieldBorder;
    return GOuterShadow(
      borderRadius: radius,
      shadows: error
          ? GOuterShadow.ring(GColors.errorRing)
          : focused
          ? GOuterShadow.ring(GColors.focusRing)
          : const [],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: BoxConstraints(minHeight: minHeight),
        padding: padding,
        alignment: alignment,
        decoration: BoxDecoration(
          color: GColors.fieldFill,
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}

/// Yorliqli matn maydoni. `obscure` bo'lsa ko'rsatish/yashirish tugmasi qo'shiladi.
class GTextField extends StatefulWidget {
  const GTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.error,
    this.obscure = false,
    this.multiline = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.maxLength,
    this.trailing,
    this.showLabel,
    this.hideLabel,
  }) : assert(
         !obscure || (showLabel != null && hideLabel != null),
         'obscure maydonga showLabel va hideLabel kerak',
       );

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;

  /// Xato matni; bo'sh satr — faqat qizil halqa (matn boshqa maydonda).
  final String? error;
  final bool obscure;
  final bool multiline;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  /// O'ng tomondagi qo'shimcha element (masalan tozalash tugmasi).
  final Widget? trailing;

  /// Parolni ko'rsatish/yashirish tugmasining ekran o'quvchi nomlari.
  final String? showLabel;
  final String? hideLabel;

  @override
  State<GTextField> createState() => _GTextFieldState();
}

class _GTextFieldState extends State<GTextField> {
  FocusNode? _ownFocus;
  late var _hidden = widget.obscure;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(GTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final field = Semantics(
      label: widget.label,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        obscureText: _hidden,
        keyboardType: widget.multiline
            ? TextInputType.multiline
            : widget.keyboardType,
        keyboardAppearance: Brightness.dark,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        minLines: widget.multiline ? 4 : 1,
        maxLines: widget.multiline ? 8 : 1,
        inputFormatters: [
          ...?widget.inputFormatters,
          if (widget.maxLength != null)
            LengthLimitingTextInputFormatter(widget.maxLength),
        ],
        cursorColor: GColors.primary,
        style: GText.onest(
          16,
          color: widget.enabled ? GColors.text : GColors.textFaint,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: GText.onest(16, color: GColors.textFaint),
        ),
      ),
    );
    final trailing = widget.obscure
        ? GIconButton(
            icon: _hidden ? GIcons.eye : GIcons.eyeSlash,
            label: _hidden ? widget.showLabel! : widget.hideLabel!,
            ghost: false,
            onPressed: () => setState(() => _hidden = !_hidden),
          )
        : widget.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(widget.label, style: GText.fieldLabel)),
        const SizedBox(height: 8),
        _FieldShell(
          focused: _focus.hasFocus,
          error: hasError,
          minHeight: widget.multiline ? 112 : 54,
          alignment: widget.multiline
              ? Alignment.topLeft
              : Alignment.centerLeft,
          padding: EdgeInsets.fromLTRB(
            16,
            widget.multiline ? 14 : 0,
            trailing != null ? 5 : 16,
            widget.multiline ? 14 : 0,
          ),
          child: trailing != null
              ? Row(
                  children: [
                    Expanded(child: field),
                    trailing,
                  ],
                )
              : field,
        ),
        if (hasError && widget.error!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const GIcon(
                  GIcons.warningCircle,
                  size: 16,
                  color: GColors.errorText,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.error!, style: GText.error)),
              ],
            ),
          ),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: 8),
          Text(widget.helper!, style: GText.caption),
        ],
      ],
    );
  }
}

/// Buferdagi matndan faqat raqamlarni oladi (kod joylashtirish uchun).
Future<String?> readClipboardDigits(int maxLength) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return digits.length > maxLength ? digits.substring(0, maxLength) : digits;
}

/// O'chirilgan kod maydoni kataklarining shaffofligi.
const _disabledCellsOpacity = .5;

/// N xonali kod (maktab kodi — 6). Bitta yashirin maydon + ko'rinadigan kataklar:
/// klaviatura, avtomatik to'ldirish va uzoq bosib joylashtirish ishlaydi.
class GCodeField extends StatefulWidget {
  const GCodeField({
    super.key,
    required this.semanticLabel,
    this.length = 6,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.error = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final String semanticLabel;
  final int length;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Kod to'liq kiritilganda bir marta chaqiriladi (qiymat o'zgarmasa takrorlanmaydi).
  final ValueChanged<String>? onCompleted;
  final bool error;

  /// `false` — faqat o'qiladi (masalan so'rov ketayotganda): kiritish va
  /// joylashtirish ishlamaydi, kataklar xiralashadi.
  final bool enabled;
  final bool autofocus;

  @override
  State<GCodeField> createState() => _GCodeFieldState();
}

class _GCodeFieldState extends State<GCodeField> {
  TextEditingController? _ownController;
  final _focus = FocusNode();
  var _lastText = '';

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _controller.addListener(_onText);
    _lastText = _controller.text;
  }

  @override
  void didUpdateWidget(GCodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
      _lastText = _controller.text;
    }
  }

  void _onFocus() => setState(() {});

  void _onText() {
    final value = _controller.text;
    // Kursor/tanlov o'zgarishi ham listener'ni chaqiradi — faqat matn o'zgarsa.
    if (value == _lastText) return;
    _lastText = value;
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  Future<void> _paste() async {
    if (!widget.enabled) return;
    final digits = await readClipboardDigits(widget.length);
    // Bufer o'qilguncha maydon o'chirilgan bo'lishi mumkin.
    if (digits == null || !mounted || !widget.enabled) return;
    _controller.value = TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _ownController?.dispose();
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final enabled = widget.enabled;
    return Semantics(
      label: widget.semanticLabel,
      value: text.split('').join(' '),
      textField: true,
      enabled: enabled,
      readOnly: !enabled,
      onTap: enabled ? _focus.requestFocus : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: enabled ? _focus.requestFocus : null,
        onLongPress: enabled ? _paste : null,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 62,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    readOnly: !enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    keyboardAppearance: Brightness.dark,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: AnimatedOpacity(
                opacity: enabled ? 1 : _disabledCellsOpacity,
                duration: const Duration(milliseconds: 140),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _cell(i, text)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int index, String text) {
    final full = text.length == widget.length;
    final focused =
        widget.enabled &&
        _focus.hasFocus &&
        (index == text.length || (full && index == widget.length - 1));
    return _FieldShell(
      focused: focused,
      error: widget.error,
      minHeight: 62,
      alignment: Alignment.center,
      child: Text(
        index < text.length ? text[index] : '',
        style: GText.display(22),
      ),
    );
  }
}
