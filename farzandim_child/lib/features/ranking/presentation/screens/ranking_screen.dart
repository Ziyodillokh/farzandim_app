// ─────────────────────────────────────────────────────────────────────
// RankingScreen — Reyting (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Logika o'zgartirilmadi: filteredUsersProvider, timeRangeProvider, navigatsiya,
// animate() stagger — hammasi saqlanadi. Faqat ko'rinish night/glass.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_theme.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/current_user_sticky_card.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_filter_chips.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_tabs.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/ranking_user_tile.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/time_range_pills.dart';
import 'package:farzandim_child/features/ranking/presentation/widgets/top_three_podium.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(filteredUsersProvider);
    final timeRange = ref.watch(timeRangeProvider);

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AppColors.parvozBg,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Night header: "Reyting" sarlavha (nav-tab — orqaga yo'q) ──
              const _RankingHeader(),
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
                                top: 8, bottom: 140),
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
        bottomNavigationBar: const ChildBottomNavigation(),
      ),
    );
  }
}

// ─── Night header: nav-tab bo'lgani uchun orqaga yo'q, faqat sarlavha ───
class _RankingHeader extends StatelessWidget {
  const _RankingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.parvozBorder)),
      ),
      child: Row(
        children: [
          // Parvoz logo aksent
          const Text(
            'Parvoz',
            style: TextStyle(
              color: AppColors.parvozGreen,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          // Vertikal ajratuvchi
          Container(
            width: 1,
            height: 18,
            color: AppColors.parvozBorder,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 4),
          // Sahifa sarlavhasi
          const Text(
            'Reyting',
            style: TextStyle(
              color: AppColors.parvozText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Trofey aksent ikona
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.parvozSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.parvozGreen,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateMascot(
      faroVariant: FaroVariant.faceExcited,
      title: "Reyting hozircha bo'sh",
      subtitle: 'Konkurslarda ishtirok eting va reytingda joy oling!',
    );
  }
}
