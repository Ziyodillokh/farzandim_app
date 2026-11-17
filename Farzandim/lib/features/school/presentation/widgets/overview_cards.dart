// "Farzandim maktabda" kartalari: davomat halqasi va sinf bilan
// taqqoslash, kelish vaqti va seriya, haftalik dinamika, yozma vazifalar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_text_fit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Davomat holatlari ranglari (kalendar va halqa bilan bir xil).
abstract final class AttendanceTone {
  static const present = SK.green;
  static const late = SK.amber;
  static const absent = SK.red;
  static const leftEarly = SK.sky;
  static const excused = SK.teal;
}

class OverviewAttendanceCard extends StatelessWidget {
  const OverviewAttendanceCard({required this.attendance, super.key});

  final OverviewAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final a = attendance;
    final marked = a.marked;
    double part(int n) => marked == 0 ? 0 : n / marked;
    final classRate = a.classRate;
    return SkCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkRing(
                size: 118,
                segments: [
                  (part(a.present), AttendanceTone.present),
                  (part(a.late), AttendanceTone.late),
                  (part(a.leftEarly), AttendanceTone.leftEarly),
                  (part(a.excused), AttendanceTone.excused),
                  (part(a.absent), AttendanceTone.absent),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      marked == 0 ? '—' : '${a.rate}%',
                      style: skDisplay(24),
                    ),
                    Text(
                      'school.attendance.rate'.tr(),
                      style: skText(10.5, c: SK.dim, height: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marked == 0
                          ? 'school.overview.noMarks'.tr()
                          : 'school.overview.rateCaption'.tr(
                              namedArgs: {
                                'attended': '${a.attended}',
                                'marked': '$marked',
                              },
                            ),
                      style: skText(13.5, w: FontWeight.w500, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Count(
                          label: 'school.overview.late'.tr(),
                          value: a.late,
                          color: AttendanceTone.late,
                        ),
                        _Count(
                          label: 'school.overview.absent'.tr(),
                          value: a.absent,
                          color: AttendanceTone.absent,
                        ),
                        _Count(
                          label: 'school.overview.leftEarly'.tr(),
                          value: a.leftEarly,
                          color: AttendanceTone.leftEarly,
                        ),
                        if (a.excused > 0)
                          _Count(
                            label: 'school.overview.excused'.tr(),
                            value: a.excused,
                            color: AttendanceTone.excused,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Compare(
            label: 'school.overview.yourChild'.tr(),
            value: marked == 0 ? null : a.rate,
            color: SK.blue,
          ),
          const SizedBox(height: 10),
          if (classRate != null)
            _Compare(
              label: 'school.overview.classAvg'.tr(),
              value: classRate,
              color: SK.faint,
            )
          else
            Text(
              'school.overview.classHidden'.tr(),
              style: skText(12, c: SK.faint, height: 1.4),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
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
          Text('$label · $value', style: skText(12, height: 1.3)),
        ],
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(label, style: skText(12.5, c: SK.dim, height: 1.3)),
        ),
        Expanded(
          child: SkBar(fraction: (value ?? 0) / 100, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            value == null ? '—' : '$value%',
            textAlign: TextAlign.right,
            style: skText(13, w: FontWeight.w600, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// O'rtacha kelish vaqti va o'z vaqtida kelish seriyasi.
class OverviewHabitRow extends StatelessWidget {
  const OverviewHabitRow({required this.attendance, super.key});

  final OverviewAttendance attendance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SkStat(
            icon: SolarIconsBold.clockCircle,
            color: SK.sky,
            value: attendance.averageArrival ?? '—',
            label: 'school.overview.avgArrival'.tr(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SkStat(
            icon: SolarIconsBold.fire,
            color: SK.amber,
            value: 'school.overview.streakDays'.tr(
              namedArgs: {'count': '${attendance.onTimeStreak}'},
            ),
            label: 'school.overview.streak'.tr(),
          ),
        ),
      ],
    );
  }
}

/// 8 haftalik kelish foizi ustunlari.
class OverviewWeeksCard extends StatelessWidget {
  const OverviewWeeksCard({required this.weeks, super.key});

  final List<WeekRate> weeks;

  static const double _chartHeight = 96;

  /// Ustun usti (foiz) va osti (sana) yozuvlari shrifti.
  static const double _rateFont = 10.5;
  static const double _dateFont = 9.5;
  static const double _labelLineHeight = 1.2;

  /// Ustun ustidagi va ostidagi oraliqlar (4 + 6) va yaxlitlash zaxirasi.
  static const double _labelGaps = 12;

  @override
  Widget build(BuildContext context) {
    // Yozuvlar balandligi shrift kattaligi bilan o'sadi — ustunlar sig'adi.
    final scaler = MediaQuery.textScalerOf(context);
    final labels =
        (scaler.scale(_rateFont) + scaler.scale(_dateFont)) * _labelLineHeight +
        _labelGaps;
    return SkCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'school.overview.weeks'.tr(),
            style: skText(15, w: FontWeight.w600),
          ),
          Text('school.overview.weeksHint'.tr(), style: skText(12, c: SK.dim)),
          const SizedBox(height: 16),
          SizedBox(
            height: _chartHeight + labels,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, w) in weeks.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _WeekBar(week: w, last: i == weeks.length - 1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({required this.week, required this.last});

  final WeekRate week;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final rate = week.rate;
    final color = rate == null
        ? Colors.white.withValues(alpha: 0.06)
        : rate >= 95
        ? AttendanceTone.present
        : rate >= 80
        ? SK.sky
        : rate >= 60
        ? AttendanceTone.late
        : AttendanceTone.absent;
    final height = rate == null
        ? 10.0
        : (OverviewWeeksCard._chartHeight * rate / 100)
              .clamp(10, OverviewWeeksCard._chartHeight)
              .toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _OneLine(
          rate == null ? '' : '$rate',
          style: skText(
            OverviewWeeksCard._rateFont,
            c: last ? SK.text : SK.dim,
            w: FontWeight.w600,
            height: OverviewWeeksCard._labelLineHeight,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: color.withValues(alpha: last ? 1 : 0.75),
            border: last
                ? Border.all(color: Colors.white.withValues(alpha: 0.5))
                : null,
          ),
        ),
        const SizedBox(height: 6),
        _OneLine(
          formatSchoolDayShort(week.weekStart),
          style: skText(
            OverviewWeeksCard._dateFont,
            c: SK.faint,
            height: OverviewWeeksCard._labelLineHeight,
          ),
        ),
      ],
    );
  }
}

/// Tor ustun yozuvi: hech qachon ikkiga bo'linmaydi — sig'masa kichrayadi.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

/// Yozma vazifalar: topshirish ulushi va yaqin / muddati o'tganlari.
class OverviewTasksCard extends StatelessWidget {
  const OverviewTasksCard({
    required this.tasks,
    required this.today,
    super.key,
  });

  final OverviewTasks tasks;

  /// "YYYY-MM-DD" (muddat yorlig'i uchun).
  final String today;

  @override
  Widget build(BuildContext context) {
    final t = tasks;
    final classRate = t.classSubmitRate;
    return SkCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkIconBubble(icon: SolarIconsBold.notebook, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'school.overview.tasks'.tr(),
                  style: skText(15, w: FontWeight.w600),
                ),
              ),
              if (t.total > 0)
                Text(
                  'school.overview.tasksSubmitted'.tr(
                    namedArgs: {
                      'submitted': '${t.submitted}',
                      'total': '${t.total}',
                    },
                  ),
                  style: skText(12.5, c: SK.dim),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (t.total == 0)
            Text(
              'school.overview.tasksEmpty'.tr(),
              style: skText(13, c: SK.dim),
            )
          else ...[
            SkBar(fraction: t.submitRate / 100, color: SK.green),
            if (classRate != null) ...[
              const SizedBox(height: 8),
              Text(
                'school.overview.classSubmit'.tr(
                  namedArgs: {'rate': '$classRate'},
                ),
                style: skText(12, c: SK.faint),
              ),
            ],
            for (final item in t.items) ...[
              const SizedBox(height: 12),
              _TaskRow(task: item, today: today),
            ],
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.today});

  final OverviewTask task;
  final String today;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.state) {
      TaskState.overdue => SK.red,
      TaskState.returned => SK.amber,
      TaskState.accepted => SK.green,
      TaskState.submitted => SK.sky,
      TaskState.todo => SK.dim,
    };
    final tomorrow = DateTime.tryParse(today)?.add(const Duration(days: 1));
    String two(int v) => v.toString().padLeft(2, '0');
    final tomorrowKey = tomorrow == null
        ? ''
        : '${tomorrow.year}-${two(tomorrow.month)}-${two(tomorrow.day)}';
    final due = task.state == TaskState.todo && task.dueDate == today
        ? 'school.overview.dueToday'.tr()
        : task.state == TaskState.todo && task.dueDate == tomorrowKey
        ? 'school.overview.dueTomorrow'.tr()
        : 'school.overview.due'.tr(
            namedArgs: {'date': formatSchoolDay(task.dueDate)},
          );
    final teacher = task.teacher;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SK.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: skText(13.5, w: FontWeight.w500, height: 1.35),
          ),
          const SizedBox(height: 8),
          SkTagRow(
            leading: Text(
              [?teacher, due].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: skText(11.5, c: SK.dim, height: 1.35),
            ),
            tag: SkTag(
              label: 'school.overview.state.${task.state.name}'.tr(),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
