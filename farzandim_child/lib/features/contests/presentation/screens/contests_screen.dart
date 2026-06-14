// ─────────────────────────────────────────────────────────────────────
// ContestsScreen — Konkurslar (PDF p13-14)
// ─────────────────────────────────────────────────────────────────────
//
// Top header → 'Konkurslar' sarlavha → Aktiv/Yakunlangan tabs →
// ContestCard ListView. Empty state'lar ham bor.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/contest_card.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/contests_tabs.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(contestsActiveTabProvider);
    final activeContests = ref.watch(activeContestsProvider);
    final finishedContests = ref.watch(finishedContestsProvider);
    final loading = ref.watch(contestsLoadingProvider);
    final hasError = ref.watch(contestsErrorProvider);

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Konkurslar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: context.adaptive.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/ranking'),
                      behavior: HitTestBehavior.opaque,
                      child: const Row(
                        children: [
                          Icon(Icons.leaderboard,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 4),
                          Text(
                            'Reyting',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const ContestsTabs(),
              const SizedBox(height: 16),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : hasError
                        ? _ErrorState(
                            onRetry: () =>
                                ref.invalidate(backendContestsProvider),
                          )
                        : activeTab == 0
                            ? _List(contests: activeContests, isActive: true)
                            : _List(
                                contests: finishedContests, isActive: false),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.contests, required this.isActive});

  final List<ContestModel> contests;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (contests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? AppIcons.trophy : Icons.history,
              size: 64,
              color: context.adaptive.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              isActive
                  ? "Hozircha aktiv konkurs yo'q"
                  : "Hozircha yakunlangan konkurs yo'q",
              style: TextStyle(
                fontSize: 16,
                color: context.adaptive.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: contests.length,
      itemBuilder: (_, i) => ContestCard(contest: contests[i]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: context.adaptive.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "Konkurslarni yuklab bo'lmadi",
            style: TextStyle(
              fontSize: 16,
              color: context.adaptive.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Internet aloqasini tekshiring',
            style: TextStyle(
              fontSize: 13,
              color: context.adaptive.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Qayta urinish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
