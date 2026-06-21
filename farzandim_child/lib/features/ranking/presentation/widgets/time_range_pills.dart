// ─────────────────────────────────────────────────────────────────────
// TimeRangePills — Kunlik / Haftalik / Oylik / Butun davr (Parvoz NIGHT)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimeRangePills extends ConsumerWidget {
  const TimeRangePills({super.key});

  static const List<String> _labels = [
    'Kunlik',
    'Haftalik',
    'Oylik',
    'Butun davr',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(timeRangeProvider);
    final ranges = TimeRange.values;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final range = ranges[i];
          final isActive = range == active;

          return GestureDetector(
            onTap: () =>
                ref.read(timeRangeProvider.notifier).state = range,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.parvozGreen
                    : AppColors.parvozSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive
                      ? AppColors.parvozGreen
                      : AppColors.parvozBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: isActive
                      ? AppColors.parvozOnGreen
                      : AppColors.parvozTextDim,
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
