// ─────────────────────────────────────────────────────────────────────
// ScheduleMiniCard — Dashboard'da bugungi jadval qisqacha ko'rinishi
// ─────────────────────────────────────────────────────────────────────
//
// Bugungi jadvallar soni va keyingi/hozirgi tadbir ko'rsatiladi.
// Tap → /schedules ekraniga to'liq ro'yxat uchun.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScheduleMiniCard extends ConsumerWidget {
  const ScheduleMiniCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todaySchedulesProvider);
    final current = ref.watch(currentScheduleProvider);
    final next = ref.watch(nextScheduleProvider);

    final String subtitle;
    if (current != null) {
      subtitle = 'dashboard.scheduleNow'
          .tr(namedArgs: {'title': current.title});
    } else if (next != null) {
      subtitle = 'dashboard.scheduleNext'
          .tr(namedArgs: {'title': next.title});
    } else if (today.isEmpty) {
      subtitle = 'dashboard.scheduleEmpty'.tr();
    } else {
      subtitle = 'dashboard.scheduleAllDone'.tr();
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'dashboard.scheduleMiniTitle'.tr(
                      namedArgs: {'count': '${today.length}'},
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              AppIcons.chevronRight,
              color: AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
