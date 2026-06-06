// ─────────────────────────────────────────────────────────────────────
// RankingTabs — Umumiy / Hudud / Yosh segmented control
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RankingTabs extends ConsumerWidget {
  const RankingTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(rankingTabProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.adaptive.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.adaptive.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Tab(
                tab: RankingTab.umumiy,
                label: 'Umumiy',
                icon: Icons.public,
                activeTab: activeTab,
              ),
            ),
            Expanded(
              child: _Tab(
                tab: RankingTab.hudud,
                label: 'Hudud',
                icon: AppIcons.mapPin,
                activeTab: activeTab,
              ),
            ),
            Expanded(
              child: _Tab(
                tab: RankingTab.yoshGuruhi,
                label: 'Yosh',
                icon: Icons.cake,
                activeTab: activeTab,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends ConsumerWidget {
  const _Tab({
    required this.tab,
    required this.label,
    required this.icon,
    required this.activeTab,
  });

  final RankingTab tab;
  final String label;
  final IconData icon;
  final RankingTab activeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = tab == activeTab;

    return GestureDetector(
      onTap: () => ref.read(rankingTabProvider.notifier).state = tab,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? Colors.black
                  : context.adaptive.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.black
                    : context.adaptive.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
