// ─────────────────────────────────────────────────────────────────────
// TopThreePodium — 1-o'rin (gold, center) / 2 (silver, left) / 3 (bronze, right)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopThreePodium extends ConsumerWidget {
  const TopThreePodium({super.key});

  static const Color _gold = AppColors.catGold;
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(filteredUsersProvider);
    if (users.length < 3) return const SizedBox.shrink();

    final timeRange = ref.watch(timeRangeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumPosition(
              user: users[1],
              position: 2,
              color: _silver,
              height: 110,
              timeRange: timeRange,
            ),
          ),
          Expanded(
            child: _PodiumPosition(
              user: users[0],
              position: 1,
              color: _gold,
              height: 140,
              timeRange: timeRange,
              isCrowned: true,
            ),
          ),
          Expanded(
            child: _PodiumPosition(
              user: users[2],
              position: 3,
              color: _bronze,
              height: 90,
              timeRange: timeRange,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPosition extends StatelessWidget {
  const _PodiumPosition({
    required this.user,
    required this.position,
    required this.color,
    required this.height,
    required this.timeRange,
    this.isCrowned = false,
  });

  final RankingUser user;
  final int position;
  final Color color;
  final double height;
  final TimeRange timeRange;
  final bool isCrowned;

  @override
  Widget build(BuildContext context) {
    final score = scoreFor(user, timeRange);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isCrowned)
          const Icon(Icons.workspace_premium,
              color: AppColors.catGold, size: 28),
        if (isCrowned) const SizedBox(height: 4),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: user.avatarColor,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.backgroundBottom, width: 2),
              ),
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color,
                // ignore: deprecated_member_use
                color.withOpacity(0.5),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
