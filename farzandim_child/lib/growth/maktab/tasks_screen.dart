// M02 · Maktab vazifalari: muddat bo'yicha guruhlar — muddati o'tgan, bugun,
// keyingi kunlar, bajarilgan. Har qatorda fan/tur, o'qituvchi, taxminiy vaqt
// va holat; bosilsa M03 (yozma vazifa ham M03 orqali M08 ga).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SchoolTasksScreen extends ConsumerWidget {
  const SchoolTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final async = ref.watch(schoolAssignmentsProvider);
    final tasks = async.valueOrNull ?? const <SchoolAssignment>[];
    final today = dateOnly(now);
    final done = <SchoolAssignment>[];
    final overdue = <SchoolAssignment>[];
    final dueToday = <SchoolAssignment>[];
    final upcoming = <SchoolAssignment>[];
    for (final t in tasks) {
      final due = t.dueDate;
      if (taskFinished(t)) {
        done.add(t);
      } else if (t.isOverdue || (due != null && due.isBefore(today))) {
        overdue.add(t);
      } else if (due != null && sameDay(due, today)) {
        dueToday.add(t);
      } else {
        upcoming.add(t);
      }
    }
    int byDue(SchoolAssignment a, SchoolAssignment b) =>
        (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100));
    upcoming.sort(byDue);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.school.tasksScreen.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(schoolAssignmentsProvider),
        children: [
          if (async.isLoading && !async.hasValue)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (tasks.isEmpty)
            GNote(
              text: 'g5.school.noTasks'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.clipboardText,
            ),
          for (final (key, list) in [
            ('overdue', overdue),
            ('today', dueToday),
            ('upcoming', upcoming),
            ('done', done),
          ])
            if (list.isNotEmpty)
              GSection(
                title: 'g5.school.tasksScreen.$key'.tr(),
                child: GList(
                  children: [for (final t in list) _TaskRow(task: t, now: now)],
                ),
              ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.now});

  final SchoolAssignment task;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = taskStatus(task);
    final meta = [
      taskKindLine(task),
      if (task.dueDate != null) dueLabel(task.dueDate, now),
      if (task.teacherName != null && task.teacherName!.isNotEmpty)
        task.teacherName!,
      if (task.estimatedMinutes != null)
        'g5.school.tasksScreen.minutes'.tr(
          namedArgs: {'count': '${task.estimatedMinutes}'},
        ),
    ].join(' · ');
    return GListItem(
      leading: taskTile(task),
      title: taskTitle(task),
      subtitle: meta,
      // «Boshlanmagan» — odatiy holat, qatorni toraytirmaslik uchun chip yo'q.
      trailing: status.kind == GChipKind.neutral
          ? null
          : GChip(label: status.label, kind: status.kind),
      onTap: () => GrowthLinks.schoolTask(context, task.id),
    );
  }
}
