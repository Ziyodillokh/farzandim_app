// ─────────────────────────────────────────────────────────────────────
// RankingScreen — Reyting (PDF p19-20)
// ─────────────────────────────────────────────────────────────────────
//
// Top header → 'Reyting' → Tabs → Time pills → Filter chips →
// TopThreePodium + ListView (4..N) + sticky CurrentUserStickyCard.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/current_user_sticky_card.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_filter_chips.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_tabs.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_user_tile.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/time_range_pills.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/top_three_podium.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(filteredUsersProvider);
    final timeRange = ref.watch(timeRangeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DashboardTopHeader(
                  onAvatarTap: () => context.push('/account-edit'),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reyting',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const RankingTabs(),
              const SizedBox(height: 12),
              const TimeRangePills(),
              const RankingFilterChips(),
              Expanded(
                child: users.length < 4
                    ? const _EmptyState()
                    : Stack(
                        children: [
                          ListView(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 120),
                            children: [
                              const TopThreePodium(),
                              const SizedBox(height: 16),
                              // Stagger: 4-o'rindan boshlab har user 40ms kechikish bilan
                              for (int i = 3; i < users.length; i++)
                                RankingUserTile(
                                  user: users[i],
                                  rank: i + 1,
                                  timeRange: timeRange,
                                )
                                    .animate()
                                    .fadeIn(
                                      duration: 250.ms,
                                      delay: (40 * (i - 3)).ms,
                                    )
                                    .slideX(
                                      begin: 0.1,
                                      end: 0,
                                      duration: 250.ms,
                                      delay: (40 * (i - 3)).ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                            ],
                          ),
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: CurrentUserStickyCard(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // FARO faceExcited — bola konkurslarga qatnashishga motivatsiya
    return const EmptyStateMascot(
      faroVariant: FaroVariant.faceExcited,
      title: "Reyting hozircha bo'sh",
      subtitle: 'Konkurslarda ishtirok eting va reytingda joy oling!',
    );
  }
}
