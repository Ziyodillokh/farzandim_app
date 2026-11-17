// Davomat bo'laklari: holat belgisi, kelish / ketish vaqtlari, QR tugmasi
// va sinf / dars vaqti qatori (bosh sahifa kartasi, "Maktabim", QR natijasi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/attendance_display.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Vaqt hali yo'q (kelmagan / ketmagan).
const kNoAttendanceTime = '—';

/// Holat belgisi rangi.
Color attendanceChipColor(AttendanceChipKind kind) => switch (kind) {
  AttendanceChipKind.present => HomeColors.green,
  AttendanceChipKind.late => HomeColors.amber,
  AttendanceChipKind.absent => SchoolColors.absent,
  AttendanceChipKind.leftEarly => HomeColors.orange,
  AttendanceChipKind.excused || AttendanceChipKind.marked => HomeColors.blue,
  AttendanceChipKind.notMarked ||
  AttendanceChipKind.dayOff => HomeColors.textDim,
};

/// "5-A sinf · 08:00–13:25" — sinf yoki smena bo'lmasa qisqaroq / `null`.
String? schoolScheduleLine(SchoolToday today) {
  final className = today.className;
  final shift = today.shift;
  final parts = [
    if (className != null)
      'school.today.className'.tr(namedArgs: {'name': className}),
    if (shift != null)
      'school.today.timeRange'.tr(
        namedArgs: {'start': shift.start, 'end': shift.end},
      ),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Bugungi holat belgisi — rangli nuqta + nom. Kengligi cheklangan (uzun
/// nom qisqartiriladi), shuning uchun istalgan qatorga qo'yish mumkin.
class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({
    super.key,
    required this.kind,
    this.maxWidth = 160,
  });

  final AttendanceChipKind kind;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final color = attendanceChipColor(kind);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              kind.labelKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeText(
                12,
                weight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kelgan va ketgan vaqt plitkalari (Toshkent vaqti, serverdan "HH:MM").
class AttendanceTimes extends StatelessWidget {
  const AttendanceTimes({super.key, required this.record});

  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TimeTile(
              icon: SolarIconsOutline.login,
              label: 'school.today.arrived'.tr(),
              time: record?.inAt,
              color: HomeColors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TimeTile(
              icon: SolarIconsOutline.logout,
              label: 'school.today.left'.tr(),
              time: record?.outAt,
              color: HomeColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String? time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: time == null ? HomeColors.textDim : color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FitText(
                  label,
                  style: homeText(11.5, color: HomeColors.textDim, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  time ?? kNoAttendanceTime,
                  maxLines: 1,
                  style: homeDisplay(17, weight: FontWeight.w700, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "QR orqali kirish / chiqish" — asosiy tugma (QR belgisi bilan).
class SchoolScanButton extends StatelessWidget {
  const SchoolScanButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 44,
  });

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.primary,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  SolarIconsOutline.qrCode,
                  size: 19,
                  color: Colors.white,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: FitText(
                    label,
                    style: homeText(14, weight: FontWeight.w700, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
