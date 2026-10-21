// "Maktabim" — bugungi davomat bo'limi: sana, sinf va smena, dars vaqti,
// holat belgisi, kelish / ketish vaqti, bolaga yo'l-yo'riq va
// "QR orqali kirish / chiqish" (o'quv kuni, hali chiqmagan bo'lsa).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/attendance_display.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/widgets/attendance_widgets.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class AttendanceSection extends StatelessWidget {
  const AttendanceSection({super.key, required this.today});

  final SchoolToday today;

  @override
  Widget build(BuildContext context) {
    final date = today.date;
    final classLine = _classLine(today);
    final shift = today.shift;
    return Container(
      decoration: homeCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'school.today.title'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(18, weight: FontWeight.w800, height: 1.25),
                ),
              ),
              const SizedBox(width: 8),
              AttendanceStatusChip(kind: attendanceChipOf(today)),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 2),
            Text(
              'school.today.dateLine'.tr(
                namedArgs: {'date': localizedDayMonth(date)},
              ),
              style: homeText(13, color: HomeColors.textDim),
            ),
          ],
          if (classLine != null || shift != null) const SizedBox(height: 12),
          if (classLine != null)
            _InfoRow(
              icon: SolarIconsOutline.squareAcademicCap,
              text: classLine,
            ),
          if (classLine != null && shift != null) const SizedBox(height: 6),
          if (shift != null)
            _InfoRow(
              icon: SolarIconsOutline.clockCircle,
              text: 'school.today.hours'.tr(
                namedArgs: {'start': shift.start, 'end': shift.end},
              ),
            ),
          const SizedBox(height: 12),
          AttendanceTimes(record: today.record),
          const SizedBox(height: 12),
          SchoolNote(text: attendanceHintKey(today).tr()),
          if (today.canScan) ...[
            const SizedBox(height: 14),
            SchoolScanButton(
              label: scanLabelKey(today).tr(),
              height: 50,
              onTap: () => openSchoolCheckIn(context),
            ),
          ],
        ],
      ),
    );
  }

  /// "5-A sinf · 1-smena" (bo'lmagan qism tushirib qoldiriladi).
  static String? _classLine(SchoolToday today) {
    final className = today.className;
    final shiftName = today.shift?.name.trim() ?? '';
    final parts = [
      if (className != null)
        'school.today.className'.tr(namedArgs: {'name': className}),
      if (shiftName.isNotEmpty) shiftName,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: HomeColors.textDim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: homeText(14, weight: FontWeight.w600, height: 1.3),
          ),
        ),
      ],
    );
  }
}
