// Oy kalendari: test yechilgan kunlar natija darajasi rangida, bugun —
// ko'k halqa, tanlangan kun — to'liq ko'k. Kelajak kunlar xira.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/result_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.dayPercent,
    required this.onSelect,
    this.onPrev,
    this.onNext,
  });

  /// Oyning istalgan kuni.
  final DateTime month;
  final DateTime today;
  final DateTime selected;

  /// Kun (soatsiz) → shu kundagi natija foizi.
  final Map<DateTime, int> dayPercent;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final cells = offset + daysInMonth;
    final rows = (cells / 7).ceil();
    final weekdays = 'common.weekdaysShort'.tr().split(',');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: homeCardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _NavButton(
                icon: SolarIconsOutline.altArrowLeft,
                label: 'learn.prevMonth'.tr(),
                onTap: onPrev,
              ),
              Expanded(
                child: Text(
                  '${monthNameFrom('learn.monthsNominative'.tr(), month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: homeText(16.5, weight: FontWeight.w800),
                ),
              ),
              _NavButton(
                icon: SolarIconsOutline.altArrowRight,
                label: 'learn.nextMonth'.tr(),
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      i < weekdays.length ? weekdays[i].trim() : '',
                      style: homeText(12, color: HomeColors.textDim),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cell(r * 7 + c - offset + 1, daysInMonth)),
              ],
            ),
          const SizedBox(height: 10),
          const _Legend(),
        ],
      ),
    );
  }

  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 44);
    final date = DateTime(month.year, month.month, day);
    final percent = dayPercent[date];
    final isFuture = date.isAfter(today);
    final isToday = isSameDay(date, today);
    final isSelected = isSameDay(date, selected);
    final level = percent == null
        ? null
        : percent >= kSuccessPercent
        ? ScoreLevel.good
        : percent >= 60
        ? ScoreLevel.medium
        : ScoreLevel.low;
    final colors = level == null ? null : scoreColors(level);

    final Color fill;
    final Color textColor;
    Color? border;
    if (isSelected) {
      fill = HomeColors.primary;
      textColor = Colors.white;
    } else if (colors != null) {
      fill = colors.$3;
      textColor = colors.$1;
      border = colors.$2;
    } else {
      fill = Colors.transparent;
      textColor = isFuture
          ? HomeColors.textDim.withValues(alpha: 0.35)
          : Colors.white;
    }
    if (isToday && !isSelected) border = HomeColors.primary;

    return Semantics(
      button: !isFuture,
      selected: isSelected,
      label: percent == null ? null : '$percent%',
      child: GestureDetector(
        onTap: isFuture
            ? null
            : () {
                HapticFeedback.selectionClick();
                onSelect(date);
              },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: border == null
                    ? null
                    : Border.all(color: border, width: isToday ? 1.6 : 1),
              ),
              child: Text(
                '$day',
                style: homeText(
                  14,
                  weight: percent != null || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? HomeColors.textDim.withValues(alpha: 0.3)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(ScoreLevel level, String text) {
      final (color, border, bg) = scoreColors(level);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: homeText(12, color: HomeColors.textDim)),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        item(ScoreLevel.good, '≥ 80%'),
        item(ScoreLevel.medium, '60–79%'),
        item(ScoreLevel.low, '< 60%'),
      ],
    );
  }
}
