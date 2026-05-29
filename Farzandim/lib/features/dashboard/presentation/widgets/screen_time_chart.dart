// ─────────────────────────────────────────────────────────────────────
// ScreenTimeChart — Parent dashboard haftalik bar chart
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.x: Child App'dan ko'chirildi (parent monitoring vositasi).
// Tanlangan bola uchun oxirgi 7 kunlik app-usage aggregati.
// Bugungi kun lime green bar, qolganlar slate.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 7 kunlik usage provider — selectedChildId family.
final weeklyChildUsageProvider =
    FutureProvider.family<List<DailyUsageTotal>, String>((ref, childId) async {
  final repo = ref.watch(backendAppUsageRepositoryProvider);
  return repo.getWeeklyTotals(childId: childId, endDate: DateTime.now());
});

class ScreenTimeChart extends ConsumerWidget {
  const ScreenTimeChart({super.key, required this.childId});

  final String childId;

  static const List<String> _shortDays = [
    'Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya',
  ];
  static const Color _todayBar = AppColors.primary;
  static const Color _otherBar = AppColors.surfaceVariant;
  static const TextStyle _yAxisStyle = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAsync = ref.watch(weeklyChildUsageProvider(childId));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: weeklyAsync.when(
        loading: () => const SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) => SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Statistika yuklanmadi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(weeklyChildUsageProvider(childId)),
                  child: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        ),
        data: (totals) => _buildChart(totals),
      ),
    );
  }

  Widget _buildChart(List<DailyUsageTotal> totals) {
    if (totals.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            "Hech qanday ma'lumot yo'q",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final todayKey = _key(DateTime.now());
    final maxMs = totals
        .map((t) => t.totalMs)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxHours = (maxMs / 3600000).ceil().clamp(2, 24);

    // Bugungi kun jami vaqti.
    final todayTotal = totals
        .firstWhere(
          (t) => _key(t.date) == todayKey,
          orElse: () => totals.last,
        )
        .totalMs;
    final hours = todayTotal ~/ 3600000;
    final minutes = (todayTotal % 3600000) ~/ 60000;
    final title = hours == 0 ? '$minutes daq' : '$hours st $minutes daq';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ekran vaqti',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: totals.map((daily) {
                    final value = daily.hours;
                    final isToday = _key(daily.date) == todayKey;
                    final heightPercent = value / maxHours;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: (heightPercent * 140).clamp(2, 140),
                          decoration: BoxDecoration(
                            color: isToday ? _todayBar : _otherBar,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _shortDays[(daily.date.weekday - 1) % 7],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$maxHours st', style: _yAxisStyle),
                  Text('${(maxHours / 2).floor()} st', style: _yAxisStyle),
                  const Text('0', style: _yAxisStyle),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
