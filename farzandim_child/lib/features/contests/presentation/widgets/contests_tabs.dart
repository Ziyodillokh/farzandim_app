// ─────────────────────────────────────────────────────────────────────
// ContestsTabs — Aktiv/Yakunlangan pill segmented control
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContestsTabs extends ConsumerWidget {
  const ContestsTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(contestsActiveTabProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Tab(
                index: 0,
                label: 'Aktiv',
                isActive: activeTab == 0,
              ),
            ),
            Expanded(
              child: _Tab(
                index: 1,
                label: 'Yakunlangan',
                isActive: activeTab == 1,
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
    required this.index,
    required this.label,
    required this.isActive,
  });

  final int index;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(contestsActiveTabProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
