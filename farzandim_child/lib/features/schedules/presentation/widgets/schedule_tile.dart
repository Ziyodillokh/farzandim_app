// ─────────────────────────────────────────────────────────────────────
// ScheduleTile — bitta jadval qatori (Telegram-style card)
// ─────────────────────────────────────────────────────────────────────
//
// `isCurrent` rost bo'lsa lime green border + "HOZIR" badge.

import 'package:flutter/material.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';

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
        return Icons.school;
      case ScheduleType.sport:
        return Icons.sports_soccer;
      case ScheduleType.sleep:
        return Icons.nightlight_round;
      case ScheduleType.meal:
        return Icons.restaurant;
      case ScheduleType.custom:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _typeIcon(schedule.type),
              color: isCurrent ? Colors.black : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        schedule.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'HOZIR',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.timeRangeFormatted,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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
