// ─────────────────────────────────────────────────────────────────────
// PrimaryButton — Sprint UI.2 PlayfulButton wrapper (backwards compat)
// ─────────────────────────────────────────────────────────────────────
//
// Eski API saqlandi (text, onPressed, isLoading, icon).
// Ichida PlayfulButton (3D shadow + press anim + haptic) ishlatiladi.
//
// Yangi kodda to'g'ridan-to'g'ri `PlayfulButton(label:, ...)` ishlatish
// tavsiya etiladi — boshqa variant'lar (secondary/accent/warning/danger/
// outlined) uchun.

import 'package:farzandim_child/shared/widgets/playful_button.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  /// Tugma matni (Caps Lock tavsiya etiladi).
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PlayfulButton(
      label: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      height: 60,
    );
  }
}
