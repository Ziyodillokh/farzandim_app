// M07 · Dars jadvali: hafta kuni tanlagichi (Du…Sh), sinf va smena, vaqt
// bo'yicha dars kartalari — hozirgi va keyingi dars ajratiladi; shu fandan
// shu kunga muddatli vazifa bo'lsa «Vazifa bor» (M03). Dam olish/bayram va
// «Jadval hali e'lon qilinmagan» alohida.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_models.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(learningClockProvider)();
    final today = dateOnly(now);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    // Yakshanba bo'lsa — keyingi hafta ko'rsatiladi.
    final weekStart = today.weekday == DateTime.sunday
        ? monday.add(const Duration(days: 7))
        : monday;
    final date =
        _date ?? (today.weekday == DateTime.sunday ? weekStart : today);
    final async = ref.watch(schoolTimetableProvider(date));
    final day = async.valueOrNull;
    final tasks =
        ref.watch(schoolAssignmentsProvider).valueOrNull ??
        const <SchoolAssignment>[];
    final error = async.error;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.school.timetableScreen.title'.tr(),
          subtitle: day?.className == null
              ? null
              : 'g5.school.timetableScreen.classShift'.tr(
                  namedArgs: {
                    'class': day!.className!,
                    'shift': day.shiftName ?? '',
                  },
                ),
        ),
        onRefresh: () async => ref.invalidate(schoolTimetableProvider(date)),
        children: [
          _DayPicker(
            weekStart: weekStart,
            selected: date,
            today: today,
            onSelect: (d) => setState(() => _date = d),
          ),
          if (async.isLoading && day == null)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (error is SchoolException &&
              error.code == SchoolErrorCode.unavailable)
            GNote(
              text: 'g5.school.timetableScreen.notPublished'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.calendarDots,
            )
          else if (error != null && day == null)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(schoolTimetableProvider(date)),
              ),
            )
          else if (day != null)
            ..._lessons(day, now, tasks),
        ],
      ),
    );
  }

  List<Widget> _lessons(
    TimetableDay day,
    DateTime now,
    List<SchoolAssignment> tasks,
  ) {
    if (day.dayOff == DayOffReason.holiday) {
      return [
        GNote(
          text: 'g5.school.timetableScreen.holiday'.tr(
            namedArgs: {'name': day.holidayName ?? ''},
          ),
          kind: GNoteKind.ok,
          icon: GIcons.sparkle,
        ),
      ];
    }
    if (day.dayOff == DayOffReason.weekend) {
      return [
        GNote(
          text: 'g5.school.timetableScreen.weekend'.tr(),
          kind: GNoteKind.plain,
          icon: GIcons.sparkle,
        ),
      ];
    }
    if (!day.published || day.lessons.isEmpty) {
      return [
        GNote(
          text: 'g5.school.timetableScreen.notPublished'.tr(),
          kind: GNoteKind.plain,
          icon: GIcons.calendarDots,
        ),
      ];
    }
    final isToday = sameDay(day.date, now);
    final marks = isToday ? currentLessons(day, now) : (now: null, next: null);
    return [
      for (final lesson in day.lessons)
        _LessonCard(
          lesson: lesson,
          state: switch (lesson) {
            _ when identical(lesson, marks.now) => _LessonState.now,
            _ when identical(lesson, marks.next) => _LessonState.next,
            _ when isToday && clockOn(day.date, lesson.end).isBefore(now) =>
              _LessonState.past,
            _ => _LessonState.later,
          },
          task: tasks
              .where(
                (t) =>
                    t.subject?.name == lesson.subject &&
                    t.dueDate != null &&
                    sameDay(t.dueDate!, day.date) &&
                    !taskFinished(t),
              )
              .firstOrNull,
        ),
    ];
  }
}

enum _LessonState { past, now, next, later }

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.weekStart,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime weekStart;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 6; i++) weekStart.add(Duration(days: i))];
    return GSegmented<DateTime>(
      options: days,
      selected: days.where((d) => sameDay(d, selected)).firstOrNull,
      labelOf: (d) => sameDay(d, today)
          ? 'g5.school.timetableScreen.today'.tr()
          : 'g5.school.timetableScreen.days.${d.weekday}'.tr(),
      onChanged: onSelect,
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.state, this.task});

  final TimetableLesson lesson;
  final _LessonState state;
  final SchoolAssignment? task;

  @override
  Widget build(BuildContext context) {
    final on = state == _LessonState.now;
    final meta = [
      if (lesson.room != null && lesson.room!.isNotEmpty)
        'g5.school.timetableScreen.room'.tr(namedArgs: {'room': lesson.room!}),
      if (lesson.teacherName != null && lesson.teacherName!.isNotEmpty)
        lesson.teacherName!,
    ].join(' · ');
    final chip = switch (state) {
      _LessonState.now => GChip(
        label: 'g5.school.timetableScreen.now'.tr(),
        kind: GChipKind.info,
      ),
      _LessonState.next => GChip(label: 'g5.school.timetableScreen.next'.tr()),
      _LessonState.past => GChip(label: 'g5.school.timetableScreen.past'.tr()),
      _LessonState.later => null,
    };
    final content = Opacity(
      opacity: state == _LessonState.past ? .7 : 1,
      child: GGlass(
        kind: on ? GGlassKind.feat : GGlassKind.plain,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.start, style: GText.display(14)),
                  Text(lesson.end, style: GText.caption),
                ],
              ),
            ),
            GTile(
              icon: lessonSubjectIcon(lesson.subject),
              hue: lessonSubjectHue(lesson.subject),
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lessonSubjectLabel(lesson.subject),
                    style: GText.itemTitle,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta, style: GText.caption),
                  ],
                  if (task != null) ...[
                    const SizedBox(height: 6),
                    GChip(
                      label: 'g5.school.timetableScreen.hasTask'.tr(),
                      kind: GChipKind.warn,
                      icon: GIcons.clipboardText,
                    ),
                  ],
                ],
              ),
            ),
            if (chip != null) chip,
          ],
        ),
      ),
    );
    if (task == null) return MergeSemantics(child: content);
    return MergeSemantics(
      child: GPressable(
        onTap: () => GrowthLinks.schoolTask(context, task!.id),
        pressedScale: .98,
        child: content,
      ),
    );
  }
}
