// ─────────────────────────────────────────────────────────────────────
// ScheduleTile — bitta jadval qatori (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// `isCurrent` rost bo'lsa — aqua aksent border + "HOZIR" badge.
// Fon: parvozGlassFlat (soyasiz glass) — ro'yxat itemlar uchun mos.
// Logika (schedule model, isCurrent, type icon) O'ZGARMAGAN.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    required this.schedule,
    this.isCurrent = false,
    super.key,
  });

  final Schedule schedule;
  final bool isCurrent;

  IconData _typeIcon(ScheduleType type) {
    switch (type) {
      case ScheduleType.school:
        return Icons.school_rounded;
      case ScheduleType.sport:
        return Icons.sports_soccer_rounded;
      case ScheduleType.sleep:
        return Icons.nightlight_round;
      case ScheduleType.meal:
        return Icons.restaurant_rounded;
      case ScheduleType.custom:
        return Icons.event_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Aktiv (hozirgi) element uchun aqua border ustiga qo'shimcha aksent
    final decoration = isCurrent
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.parvozGlassTop, AppColors.parvozGlassBottom],
            ),
            border: Border.all(color: AppColors.parvozGreen, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.parvozGreen.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : parvozGlassFlat(radius: 16);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Row(
        children: [
          // ─── Tur ikoni doirasi ────────────────────────────────────
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.parvozGreen.withValues(alpha: 0.18)
                  : AppColors.parvozSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent
                    ? AppColors.parvozGreen.withValues(alpha: 0.5)
                    : AppColors.parvozBorder,
              ),
            ),
            child: Icon(
              _typeIcon(schedule.type),
              color: isCurrent
                  ? AppColors.parvozGreen
                  : AppColors.parvozTextDim,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // ─── Sarlavha + vaqt ─────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        schedule.title,
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.parvozText
                              : AppColors.parvozText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isCurrent) _HozirBadge(),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  schedule.timeRangeFormatted,
                  style: const TextStyle(
                    color: AppColors.parvozTextDim,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── "HOZIR" badge — aqua aksent ────────────────────────────────────────
class _HozirBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.parvozGreen,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.parvozGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'schedules.nowBadge'.tr(),
        style: TextStyle(
          color: AppColors.parvozOnGreen,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
