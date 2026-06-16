// ─────────────────────────────────────────────────────────────────────
// CurrentUserStickyCard — pastki yopishqoq card (Parvoz NIGHT/GLASS)
// ─────────────────────────────────────────────────────────────────────
//
// Logika (filteredUsersProvider, scoreFor, pointsToNext) o'zgartirilmadi.
// Ko'rinish: parvoz glass + aqua aksent.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrentUserStickyCard extends ConsumerWidget {
  const CurrentUserStickyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(filteredUsersProvider);
    final timeRange = ref.watch(timeRangeProvider);

    final currentUserIndex =
        users.indexWhere((u) => u.isCurrentUser);
    if (currentUserIndex == -1) return const SizedBox.shrink();

    final currentUser = users[currentUserIndex];
    final rank = currentUserIndex + 1;

    int? pointsToNext;
    if (currentUserIndex > 0) {
      final ahead = users[currentUserIndex - 1];
      final myScore = scoreFor(currentUser, timeRange);
      final aheadScore = scoreFor(ahead, timeRange);
      pointsToNext = aheadScore - myScore + 1;
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.parvozGlassTop, AppColors.parvozGlassBottom],
        ),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.parvozGreen, width: 1.5),
          left: BorderSide(color: AppColors.parvozGlassRim, width: 1),
          right: BorderSide(color: AppColors.parvozGlassRim, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 22,
            offset: Offset(0, -8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.parvozGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.parvozGreen.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.parvozGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar doira
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: currentUser.avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.parvozGreen, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.parvozGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    currentUser.name.isEmpty
                        ? '?'
                        : currentUser.name[0].toUpperCase(),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentUser.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.parvozText,
                      ),
                    ),
                    if (pointsToNext != null && pointsToNext > 0)
                      Text(
                        "Yana $pointsToNext ball — #${rank - 1} ga ko'tarilasiz!",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.parvozTextDim,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${scoreFor(currentUser, timeRange)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.parvozGreen,
                    ),
                  ),
                  const Text(
                    'ball',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.parvozTextDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
