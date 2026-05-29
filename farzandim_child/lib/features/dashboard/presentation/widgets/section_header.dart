// ─────────────────────────────────────────────────────────────────────
// SectionHeader — Dashboard bo'limlari uchun sarlavha + ixtiyoriy CTA
// ─────────────────────────────────────────────────────────────────────
//
// Misol: "Ilovadan foydalanish" sarlavha + "Barchasi →" link drill-down
// uchun. Videolar feed'da ham shunga o'xshash pattern ishlatiladi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  AppIcons.chevronRight,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
