// ─────────────────────────────────────────────────────────────────────
// TopThreePodium — 1-o'rin (gold) / 2 (silver) / 3 (bronze) (Parvoz NIGHT)
// ─────────────────────────────────────────────────────────────────────
//
// Logika (filteredUsersProvider, scoreFor, timeRange) o'zgartirilmadi.
// Ko'rinish: glass karta ichida podium, rang tokenlar parvoz*.

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.parvozGlassTop, AppColors.parvozGlassBottom],
          ),
          border: Border.all(color: AppColors.parvozGlassRim, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 22,
              offset: Offset(0, 10),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _PodiumPosition(
                user: users[1],
                position: 2,
                color: _silver,
                height: 100,
                timeRange: timeRange,
              ),
            ),
            Expanded(
              child: _PodiumPosition(
                user: users[0],
                position: 1,
                color: _gold,
                height: 130,
                timeRange: timeRange,
                isCrowned: true,
              ),
            ),
            Expanded(
              child: _PodiumPosition(
                user: users[2],
                position: 3,
                color: _bronze,
                height: 80,
                timeRange: timeRange,
              ),
            ),
          ],
        ),
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
                    color: color.withOpacity(0.45),
                    blurRadius: 12,
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
                    color: AppColors.parvozBg, width: 2),
              ),
              child: Text(
                '$position',
                style: const TextStyle(
                  color: AppColors.parvozOnGreen,
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
            color: AppColors.parvozText,
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
        // Podium ustuni — glass fon ustida rang gradient
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                // ignore: deprecated_member_use
                color.withOpacity(0.85),
                // ignore: deprecated_member_use
                color.withOpacity(0.35),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
            border: Border(
              top: BorderSide(
                  // ignore: deprecated_member_use
                  color: color.withOpacity(0.5),
                  width: 1),
              left: BorderSide(
                  // ignore: deprecated_member_use
                  color: color.withOpacity(0.3),
                  width: 1),
              right: BorderSide(
                  // ignore: deprecated_member_use
                  color: color.withOpacity(0.3),
                  width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
