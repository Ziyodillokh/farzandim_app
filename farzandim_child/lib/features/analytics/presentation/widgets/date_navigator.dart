// ─────────────────────────────────────────────────────────────────────
// DateNavigator — Sprint 4.4.32 real data integration
//                 (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// `< Bugun · 17 may 2026 >` formatdagi sana ko'rsatkichi.
// Chevron tugmalar selectedAnalyticsDateProvider'ni ±1 kun o'zgartiradi.
// Kelajak sanaga o'tish bloklangan (today > sana keyingisi).
// LOGIKA SAQLANGAN — faqat ranglar parvoz night tokenlar

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

class DateNavigator extends ConsumerWidget {
  const DateNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAnalyticsDateProvider);
    final today = _truncate(DateTime.now());
    final isFuture = !selected.isBefore(today);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(AppIcons.chevronLeft, color: AppColors.parvozText),
          tooltip: 'analytics.prevDayTooltip'.tr(),
          onPressed: () => _shift(ref, -1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _formatLabel(selected, today),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.parvozText,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            AppIcons.chevronRight,
            color: isFuture ? AppColors.parvozTextDim : AppColors.parvozText,
          ),
          tooltip: 'analytics.nextDayTooltip'.tr(),
          onPressed: isFuture ? null : () => _shift(ref, 1),
        ),
      ],
    );
  }

  static void _shift(WidgetRef ref, int days) {
    final current = ref.read(selectedAnalyticsDateProvider);
    final next = current.add(Duration(days: days));
    final today = _truncate(DateTime.now());
    if (next.isAfter(today)) return;
    ref.read(selectedAnalyticsDateProvider.notifier).state = next;
  }

  static DateTime _truncate(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _formatLabel(DateTime selected, DateTime today) {
    if (selected == today) {
      return 'analytics.dateToday'.tr(namedArgs: {'date': _short(selected)});
    }
    final diff = today.difference(selected).inDays;
    if (diff == 1) {
      return 'analytics.dateYesterday'.tr(
        namedArgs: {'date': _short(selected)},
      );
    }
    return _short(selected);
  }

  static String _short(DateTime d) {
    final locale = intl.Intl.defaultLocale ?? 'uz';
    return intl.DateFormat('d MMMM', locale).format(d);
  }
}
