// ─────────────────────────────────────────────────────────────────────
// StreakIndicator — uzluksiz kunlar counter ("🔥 10 kun")
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class StreakIndicator extends StatelessWidget {
  const StreakIndicator({required this.streak, super.key});

  final int streak;

  static const Color _fire = AppColors.catOrange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        // ignore: deprecated_member_use
        border: Border.all(color: _fire.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.streak, color: _fire, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'gamification.streakTitle'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'gamification.streakDays'
                      .tr(namedArgs: {'days': '$streak'}),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
