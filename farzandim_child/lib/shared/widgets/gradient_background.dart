// ─────────────────────────────────────────────────────────────────────
// GradientBackground — Sprint UI.1 light theme flat wrapper
// ─────────────────────────────────────────────────────────────────────
//
// Eski (Sprint 4.x): dark navy gradient (`bgTop` → `bgBottom`).
// Yangi (Sprint UI.1): light theme asosiy — flat `AppColors.bgPrimary` (oq).
//
// API saqlandi — har screen `GradientBackground(child:)` bilan o'raydi.
// Faqat fon yangilandi. Dark theme'da `bgPrimaryDark`'ga avtomatik.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimary,
      child: child,
    );
  }
}
