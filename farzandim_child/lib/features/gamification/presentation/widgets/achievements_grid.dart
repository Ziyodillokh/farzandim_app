// ─────────────────────────────────────────────────────────────────────
// AchievementsGrid — yutuq nishonlar grid'i
// ─────────────────────────────────────────────────────────────────────
//
// Hammasi 6 ta achievement ko'rinadi (Konsept v2 4.3). Unlock bo'lganlari
// rangli + ✓, qulflanmaganlari grey-out.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:flutter/material.dart';

class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({required this.unlockedIds, super.key});

  final List<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: Achievements.all.length,
      itemBuilder: (_, i) {
        final a = Achievements.all[i];
        final unlocked = unlockedIds.contains(a.id);
        return _AchievementTile(achievement: a, unlocked: unlocked);
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
  });

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? achievement.color
        // ignore: deprecated_member_use
        : AppColors.textTertiary.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          // ignore: deprecated_member_use
          color: unlocked ? color : AppColors.border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(achievement.icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.titleKey.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (unlocked) ...[
            const SizedBox(height: 2),
            Icon(AppIcons.success, color: color, size: 14),
          ],
        ],
      ),
    );
  }
}
