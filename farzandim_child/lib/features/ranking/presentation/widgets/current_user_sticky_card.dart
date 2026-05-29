// ─────────────────────────────────────────────────────────────────────
// CurrentUserStickyCard — pastki yopishqoq card (Дунё ranking)
// ─────────────────────────────────────────────────────────────────────

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // ignore: deprecated_member_use
            AppColors.primary.withOpacity(0.95),
            AppColors.primary,
          ],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: currentUser.avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
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
                        color: Colors.black,
                      ),
                    ),
                    if (pointsToNext != null && pointsToNext > 0)
                      Text(
                        "Yana $pointsToNext ball — #${rank - 1} ga ko'tarilasiz!",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.8),
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
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'ball',
                    style: TextStyle(
                      fontSize: 11,
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.7),
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
