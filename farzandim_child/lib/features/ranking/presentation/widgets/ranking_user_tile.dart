// ─────────────────────────────────────────────────────────────────────
// RankingUserTile — 4+ pozitsiyadagi user qatori
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';

class RankingUserTile extends StatelessWidget {
  const RankingUserTile({
    required this.user,
    required this.rank,
    required this.timeRange,
    super.key,
  });

  final RankingUser user;
  final int rank;
  final TimeRange timeRange;

  @override
  Widget build(BuildContext context) {
    final score = scoreFor(user, timeRange);
    final rankDiff = user.previousRank - rank;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user.isCurrentUser
            // ignore: deprecated_member_use
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: user.isCurrentUser
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Icon(
              rankDiff > 0
                  ? Icons.arrow_upward
                  : rankDiff < 0
                      ? Icons.arrow_downward
                      : Icons.remove,
              size: 14,
              color: rankDiff > 0
                  ? Colors.green
                  : rankDiff < 0
                      ? AppColors.error
                      : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: user.avatarColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: user.isCurrentUser
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (user.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SIZ',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${user.age} yosh',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (user.streakDays > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(AppIcons.streak,
                          color: Colors.orange, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${user.streakDays}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange),
                      ),
                    ],
                    if (user.badgeCount > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.military_tech,
                          color: AppColors.catGold, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${user.badgeCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.catGold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: user.isCurrentUser
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
              const Text(
                'ball',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
