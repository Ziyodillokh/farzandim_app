// ─────────────────────────────────────────────────────────────────────
// TodaySummaryChips — bugungi ekran vaqti + ilova soni (2 chip)
// ─────────────────────────────────────────────────────────────────────
//
// Greeting'dan keyin ko'rinadi. Rang qoidasi (motivatsion):
//   < 180 min (3 soat) = yashil   — yaxshi
//   180-360 min        = sariq    — o'rtacha
//   > 360 min (6 soat) = qizil    — haddan tashqari
//
// Hozircha mock qiymatlar dashboard'da hard-code'lanadi.
// Real Child Agent integratsiyasidan keyin StreamProvider'dan keladi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TodaySummaryChips extends StatelessWidget {
  const TodaySummaryChips({
    required this.screenTimeMinutes,
    required this.appCount,
    super.key,
  });

  final int screenTimeMinutes;
  final int appCount;

  Color _chipColor(int minutes) {
    if (minutes < 180) return AppColors.success;
    if (minutes < 360) return AppColors.warning;
    return AppColors.error;
  }

  String _formatScreenTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) {
      return 'dashboard.todayMinutes'.tr(namedArgs: {'min': '$mins'});
    }
    return 'dashboard.todayHoursMinutes'
        .tr(namedArgs: {'h': '$hours', 'm': '$mins'});
  }

  @override
  Widget build(BuildContext context) {
    final screenTimeColor = _chipColor(screenTimeMinutes);

    return Row(
      children: [
        Expanded(
          child: _Chip(
            icon: AppIcons.schedule,
            label: 'dashboard.summaryScreenTime'.tr(),
            value: _formatScreenTime(screenTimeMinutes),
            accentColor: screenTimeColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Chip(
            icon: Icons.apps,
            label: 'dashboard.summaryApps'.tr(),
            value: 'dashboard.summaryAppCount'
                .tr(namedArgs: {'count': '$appCount'}),
            // Sky blue — neutral aksent (ikkinchi chip uchun)
            accentColor: AppColors.catBlue,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        // ignore: deprecated_member_use
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.adaptive.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adaptive.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
