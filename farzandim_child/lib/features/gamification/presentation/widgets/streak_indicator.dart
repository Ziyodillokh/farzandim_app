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
    // DonWalletCard bilan vizual mos kelishi uchun bir xil tuzilish:
    // 14px padding, 44px doira ichida ikon, label 2 satrgacha wrap.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // ignore: deprecated_member_use
            _fire.withOpacity(0.15),
            // ignore: deprecated_member_use
            _fire.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: _fire.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: _fire.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.streak, color: _fire, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'gamification.streakTitle'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adaptive.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        '$streak',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.adaptive.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'kun',
                      style: TextStyle(
                        color: _fire,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
