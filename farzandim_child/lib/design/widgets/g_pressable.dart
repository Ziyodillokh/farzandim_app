// Bosiladigan har qanday element uchun umumiy asos: bosilganda biroz kichrayadi,
// ekran o'quvchi uchun "tugma" sifatida e'lon qilinadi.
//
// Semantika qoidasi: `semanticLabel` berilsa, ichki matnlar ekran o'quvchidan
// yashiriladi (aks holda nom ikki marta o'qiladi). Faqat ikon bo'lgan
// elementlarda yoki ko'rinadigan matnni to'liq takrorlaydigan nom bilan bering.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class GPressable extends StatefulWidget {
  const GPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.selected,
    this.exclusive = false,
    this.isButton = true,
    this.pressedScale = .97,
    this.haptic = false,
  });

  final Widget child;

  /// `null` bo'lsa element o'chirilgan (disabled) hisoblanadi.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// Tanlanadigan elementlar (segment, variant, tab) uchun holat.
  final bool? selected;

  /// `true` — bir guruhdan faqat bittasi tanlanadi (radio, segment, tab).
  final bool exclusive;
  final bool isButton;
  final double pressedScale;
  final bool haptic;

  @override
  State<GPressable> createState() => _GPressableState();
}

class _GPressableState extends State<GPressable> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final visual = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: widget.child,
    );
    return Semantics(
      button: widget.isButton,
      enabled: enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: widget.exclusive ? true : null,
      label: widget.semanticLabel,
      onTap: enabled ? widget.onTap : null,
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onLongPress: widget.onLongPress,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: widget.semanticLabel != null
            ? ExcludeSemantics(child: visual)
            : visual,
      ),
    );
  }
}
