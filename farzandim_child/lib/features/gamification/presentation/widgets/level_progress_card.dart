// ─────────────────────────────────────────────────────────────────────
// LevelProgressCard — Level + XP progress bar + keyingi status'gacha XP
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_profile.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';
import 'package:flutter/material.dart';

class LevelProgressCard extends StatelessWidget {
  const LevelProgressCard({required this.profile, super.key});

  final GamificationProfile profile;

  @override
  Widget build(BuildContext context) {
    final status = profile.status;
    final level = profile.level;
    final progress = profile.progressToNextStatus;
    final xpToNext = profile.xpToNextStatus;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'gamification.levelLabel'.tr(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$level',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: status.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  status.icon,
                  color: status.color,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // XP progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'gamification.xpTotal'
                    .tr(namedArgs: {'xp': '${profile.xp}'}),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                xpToNext > 0
                    ? 'gamification.xpToNext'
                        .tr(namedArgs: {'xp': '$xpToNext'})
                    : 'gamification.xpMaxStatus'.tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
