// ─────────────────────────────────────────────────────────────────────
// WeeklyUsageChart — Dashboard "Ilovadan foydalanish" (oxirgi 7 kun)
// ─────────────────────────────────────────────────────────────────────
//
// Reference dizayniga muvofiq: yashil vertikal ustunlar (har kun bittadan),
// balandlik o'sha kungi jami foydalanish vaqtiga proportsional. Oxirgi
// ustun (bugun) to'q yashil. Qo'shimcha chart paketi shart emas — oddiy
// Container'lar bilan chizilgan.

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/analytics/data/repositories/backend_analytics_repository.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyUsageChart extends ConsumerWidget {
  const WeeklyUsageChart({super.key});

  // Dushanba..Yakshanba (ISO weekday 1..7) — qisqa o'zbekcha.
  static const _dayLabels = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyUsageProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: context.adaptive.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.adaptive.border, width: 0.5),
      ),
      child: async.maybeWhen(
        orElse: () => const SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        data: (days) => _Chart(days: days, dayLabels: _dayLabels),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.days, required this.dayLabels});

  final List<DailyUsageTotal> days;
  final List<String> dayLabels;

  static const double _maxBarHeight = 90;

  @override
  Widget build(BuildContext context) {
    final totalMs = days.fold<int>(0, (s, d) => s + d.totalMs);
    final maxMs = days.fold<int>(1, (m, d) => d.totalMs > m ? d.totalMs : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sarlavha qatori — "Oxirgi 7 kun" + haftalik jami.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Oxirgi 7 kun',
              style: TextStyle(
                color: context.adaptive.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _fmt(totalMs),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Ustunlar.
        SizedBox(
          height: _maxBarHeight + 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(child: _bar(context, days[i], maxMs, isLast: i == days.length - 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    DailyUsageTotal day,
    int maxMs, {
    required bool isLast,
  }) {
    final ratio = (day.totalMs / maxMs).clamp(0.0, 1.0);
    final h = (ratio * _maxBarHeight).clamp(4.0, _maxBarHeight);
    final label = dayLabels[(day.date.weekday - 1).clamp(0, 6)];

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 16,
              height: h.toDouble(),
              decoration: BoxDecoration(
                // Bugun (oxirgi ustun) to'q, qolganlari ochiqroq yashil.
                color: isLast
                    ? AppColors.primary
                    // ignore: deprecated_member_use
                    : AppColors.primary.withOpacity(0.45),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isLast
                ? context.adaptive.textPrimary
                : context.adaptive.textTertiary,
            fontSize: 11,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // millisekundni "Xs Ydaq" / "Ydaq" formatiga.
  static String _fmt(int ms) {
    final totalMin = ms ~/ 60000;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h == 0) return '$m daq';
    return '$h st $m daq';
  }
}
