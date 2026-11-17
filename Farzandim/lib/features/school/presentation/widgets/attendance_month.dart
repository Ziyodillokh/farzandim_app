// ─────────────────────────────────────────────────────────────────────
// attendance_month — Davomat sahifasi: oy halqasi, kalendar, kun varag'i
// ─────────────────────────────────────────────────────────────────────
//
// `AttendanceHeroCard` — oy bo'yicha kelish foizi (rangli halqa), holatlar
// soni, o'rtacha kelish vaqti va o'z vaqtida kelish seriyasi.
// `AttendanceMonthGrid` — rangli kalendar (bugun halqada), belgilar;
// kun bosilsa `showAttendanceDaySheet`: holat, kirish / chiqish vaqti,
// kelmagan yoki kechikkan kun uchun "Sinf rahbariga yozish".

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/compose_launcher.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/overview_cards.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

Color dayStatusColor(SchoolDayStatus s) => switch (s) {
  SchoolDayStatus.present => AttendanceTone.present,
  SchoolDayStatus.late => AttendanceTone.late,
  SchoolDayStatus.absent => AttendanceTone.absent,
  SchoolDayStatus.leftEarly => AttendanceTone.leftEarly,
  SchoolDayStatus.excused => AttendanceTone.excused,
  SchoolDayStatus.pending => SK.faint,
  SchoolDayStatus.holiday || SchoolDayStatus.unknown => SK.hairline,
};

class AttendanceHeroCard extends StatelessWidget {
  const AttendanceHeroCard({
    required this.attendance,
    required this.today,
    super.key,
  });

  final MonthAttendance attendance;
  final String today;

  @override
  Widget build(BuildContext context) {
    final s = attendance.summary;
    final marked = s.total - s.pending;
    double part(int n) => marked <= 0 ? 0 : n / marked;
    final arrival = monthAverageArrival(attendance, today: today);
    final streak = monthOnTimeStreak(attendance, today: today);
    final entries = attendanceSummaryEntries(s);
    return Column(
      children: [
        SkCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Semantics(
                label: 'school.attendance.rate'.tr(),
                value: hasAttendanceRate(s) ? '${attendance.rate}%' : null,
                child: SkRing(
                  size: 112,
                  stroke: 11,
                  segments: [
                    (part(s.present), AttendanceTone.present),
                    (part(s.late), AttendanceTone.late),
                    (part(s.leftEarly), AttendanceTone.leftEarly),
                    (part(s.excused), AttendanceTone.excused),
                    (part(s.absent), AttendanceTone.absent),
                  ],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasAttendanceRate(s) ? '${attendance.rate}%' : '—',
                        style: skDisplay(23),
                      ),
                      Text(
                        'school.attendance.rate'.tr(),
                        style: skText(10.5, c: SK.dim, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAttendanceRate(s)
                          ? 'school.attendance.monthSummary'.tr(
                              namedArgs: {
                                'attended':
                                    '${s.present + s.late + s.leftEarly}',
                                'marked': '$marked',
                              },
                            )
                          : 'school.attendance.noMarks'.tr(),
                      style: skText(13.5, w: FontWeight.w500, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in entries)
                          _CountPill(
                            label: e.status.labelKey.tr(),
                            count: e.count,
                            color: dayStatusColor(e.status),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SkStat(
                icon: SolarIconsBold.clockCircle,
                color: SK.sky,
                value: arrival ?? '—',
                label: 'school.attendance.avgArrival'.tr(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SkStat(
                icon: SolarIconsBold.fire,
                color: SK.amber,
                value: 'school.overview.streakDays'.tr(
                  namedArgs: {'count': '$streak'},
                ),
                label: 'school.attendance.streak'.tr(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
              '$label · $count',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: skText(12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rangli oy kalendari; kun bosilsa — [onDay].
class AttendanceMonthGrid extends StatelessWidget {
  const AttendanceMonthGrid({
    required this.attendance,
    required this.today,
    required this.onDay,
    super.key,
  });

  final MonthAttendance attendance;
  final String today;
  final ValueChanged<AttendanceDay> onDay;

  static const _legend = [
    SchoolDayStatus.present,
    SchoolDayStatus.late,
    SchoolDayStatus.absent,
    SchoolDayStatus.leftEarly,
    SchoolDayStatus.excused,
  ];

  @override
  Widget build(BuildContext context) {
    final cells = attendanceCalendarCells(attendance, today: today);
    final byDate = {for (final d in attendance.days) d.date: d};
    return SkCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      schoolWeekdayShort(w),
                      style: skText(11.5, c: SK.faint, w: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final cell in cells)
                if (cell == null)
                  const SizedBox.shrink()
                else
                  _DayCell(
                    cell: cell,
                    onTap: byDate[cell.date] == null || cell.isFuture
                        ? null
                        : () => onDay(byDate[cell.date]!),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final s in _legend)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: dayStatusColor(s),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(s.labelKey.tr(), style: skText(11, c: SK.dim)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.cell, required this.onTap});

  final AttendanceCalendarCell cell;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = cell.isFuture ? SchoolDayStatus.unknown : cell.status;
    final color = dayStatusColor(status);
    final marked = switch (status) {
      SchoolDayStatus.present ||
      SchoolDayStatus.late ||
      SchoolDayStatus.absent ||
      SchoolDayStatus.leftEarly ||
      SchoolDayStatus.excused => true,
      _ => false,
    };
    final rest = status == SchoolDayStatus.holiday;
    return Semantics(
      button: onTap != null,
      label: '${cell.day}, ${status.labelKey.tr()}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: marked ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cell.isToday
                  ? Colors.white
                  : marked
                  ? color.withValues(alpha: 0.55)
                  : SK.hairline,
              width: cell.isToday ? 1.6 : 1,
            ),
          ),
          child: Text(
            '${cell.day}',
            style: skText(
              13,
              w: marked || cell.isToday ? FontWeight.w600 : FontWeight.w400,
              c: rest || cell.isFuture ? SK.faint : SK.text,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kun tafsiloti. `true` — ota-ona "Sinf rahbariga yozish"ni bosdi
/// (yozish varag'ini chaqiruvchi o'z kontekstida ochadi).
Future<bool> showAttendanceDaySheet(
  BuildContext context, {
  required AttendanceDay day,
  required MonthAttendance attendance,
}) async {
  final write = await showSchoolSheet<bool>(
    context,
    builder: (_) => _DaySheet(day: day, attendance: attendance),
  );
  return write ?? false;
}

/// Kelmagan / kechikkan kun haqida sinf rahbariga tayyor matn bilan yozish.
Future<void> writeAboutDay(
  BuildContext context,
  WidgetRef ref, {
  required AttendanceDay day,
  required MonthAttendance attendance,
}) => composeTo(
  context,
  ref,
  studentId: attendance.student.id,
  target: ContactTarget.homeroom,
  topic: ContactTopic.absence,
  prefill: 'school.attendance.reasonPrefill'.tr(
    namedArgs: {
      'date': formatSchoolDay(day.date),
      'student': studentFirstName(attendance.student.name),
    },
  ),
);

/// Kelmagan yoki kechikkan kunda yozish mumkin.
bool canWriteAboutDay(AttendanceDay day) {
  final status = SchoolDayStatus.of(day);
  return status == SchoolDayStatus.absent || status == SchoolDayStatus.late;
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.attendance});

  final AttendanceDay day;
  final MonthAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final status = SchoolDayStatus.of(day);
    final color = dayStatusColor(status);
    final record = day.record;
    final weekday = day.day?.weekday;
    final title = [
      if (weekday != null) schoolWeekdayShort(weekday),
      formatSchoolDay(day.date),
    ].join(', ');
    return SchoolSheetFrame(
      title: title,
      subtitle: attendance.student.name,
      children: [
        Center(
          child: SkTag(
            label: status.labelKey.tr(),
            color: color == SK.hairline ? SK.dim : color,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SkStat(
                icon: SolarIconsBold.login,
                color: SK.green,
                value: record?.inAt ?? '—',
                label: 'school.attendance.dayIn'.tr(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SkStat(
                icon: SolarIconsBold.logout,
                color: SK.sky,
                value: record?.outAt ?? '—',
                label: 'school.attendance.dayOut'.tr(),
              ),
            ),
          ],
        ),
        if (canWriteAboutDay(day)) ...[
          const SizedBox(height: 18),
          ParvozPrimaryButton(
            label: 'school.attendance.writeReason'.tr(),
            showArrow: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        const SizedBox(height: 8),
        SchoolTextButton(
          label: 'common.close'.tr(),
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
