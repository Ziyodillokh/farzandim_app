// M03 · Topshiriq tafsiloti: o'qituvchi ko'rsatmasi, fan, muddat, taxminiy
// vaqt va holat. Topshirish yo'li turiga qarab: test — mashq (U04),
// audiokitob — U12, yozma — javob yuborish (M08), maktab materiali — matn,
// havola (tashqi brauzerda) va "O'qidim".

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SchoolTaskScreen extends ConsumerWidget {
  const SchoolTaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final async = ref.watch(schoolAssignmentsProvider);
    final task = (async.valueOrNull ?? const <SchoolAssignment>[])
        .where((t) => t.id == taskId)
        .firstOrNull;
    final top = GTopBar(
      leading: GTopBar.back(
        label: 'g5.common.back'.tr(),
        onPressed: () => context.pop(),
      ),
      title: task == null ? 'g5.school.tasks'.tr() : taskTitle(task),
      subtitle: task == null ? null : taskKindLine(task),
    );
    if (task == null) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.teal,
          top: top,
          children: [
            if (async.isLoading)
              Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              )
            else
              GNote(
                text: 'g5.school.detail.notFound'.tr(),
                kind: GNoteKind.warn,
              ),
          ],
        ),
      );
    }
    final status = taskStatus(task);
    final submission = task.submission;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: top,
        dock: _action(context, ref, task),
        children: [
          GGlass(
            kind: GGlassKind.feat,
            glowHue: GHue.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    taskTile(task, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'g5.school.detail.instructions'.tr().toUpperCase(),
                            style: GText.label.copyWith(color: GColors.link),
                          ),
                          if (task.teacherName != null &&
                              task.teacherName!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              task.teacherName!,
                              style: GText.onest(
                                13,
                                weight: FontWeight.w600,
                                color: GColors.textLabel,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.note.trim().isEmpty
                      ? 'g5.school.detail.noInstructions'.tr()
                      : '«${task.note.trim()}»',
                  style: GText.body,
                ),
              ],
            ),
          ),
          if (task.lesson case final lesson?) _LessonCard(lesson: lesson),
          GList(
            children: [
              if (task.dueDate != null)
                GListItem(
                  leading: const GTile(
                    icon: GIcons.calendarDots,
                    hue: GHue.sky,
                    size: 40,
                  ),
                  title: 'g5.school.detail.due'.tr(),
                  subtitle: dueLabel(task.dueDate, now),
                ),
              if (task.estimatedMinutes != null)
                GListItem(
                  leading: const GTile(
                    icon: GIcons.timer,
                    hue: GHue.blue,
                    size: 40,
                  ),
                  title: 'g5.school.detail.estimate'.tr(),
                  subtitle: 'g5.school.tasksScreen.minutes'.tr(
                    namedArgs: {'count': '${task.estimatedMinutes}'},
                  ),
                ),
              GListItem(
                leading: const GTile(
                  icon: GIcons.checkCircle,
                  hue: GHue.green,
                  size: 40,
                ),
                title: 'g5.school.detail.status'.tr(),
                trailing: GChip(label: status.label, kind: status.kind),
              ),
            ],
          ),
          if (submission?.status == HomeworkStatus.returned &&
              (submission?.reviewNote ?? '').isNotEmpty)
            GNote(
              text:
                  '${'g5.school.detail.reviewNote'.tr()}: ${submission!.reviewNote}',
              kind: GNoteKind.warn,
              icon: GIcons.chatCircleText,
            ),
          if (task.kind == SchoolAssignmentKind.test)
            GNote(
              text: 'g5.school.detail.testRule'.tr(),
              kind: GNoteKind.plain,
            ),
        ],
      ),
    );
  }

  Widget? _action(BuildContext context, WidgetRef ref, SchoolAssignment task) {
    final subject = task.subject;
    switch (task.kind) {
      case SchoolAssignmentKind.lesson when task.isDone != true:
        return _ReadButton(taskId: task.id);
      case SchoolAssignmentKind.test
          when subject != null && task.isDone != true:
        return GButton(
          label: 'g5.school.detail.start'.tr(),
          trailingIcon: GIcons.arrowRight,
          onPressed: () => GrowthLinks.practice(context, subject),
        );
      case SchoolAssignmentKind.audiobook when task.audiobookId != null:
        return GButton(
          label: 'g5.school.detail.listen'.tr(),
          icon: GIcons.play,
          onPressed: () => GrowthLinks.audiobook(context, task.audiobookId!),
        );
      case SchoolAssignmentKind.written
          when task.submission?.status != HomeworkStatus.accepted:
        final again = task.submission != null;
        return GButton(
          label:
              (again ? 'g5.school.detail.resubmit' : 'g5.school.detail.submit')
                  .tr(),
          icon: GIcons.camera,
          onPressed: () => GrowthLinks.homeworkSubmit(context, task.id),
        );
      default:
        return null;
    }
  }
}

/// Maktab materiali matni va havolasi.
class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});

  final SchoolLesson lesson;

  @override
  Widget build(BuildContext context) {
    final link = lesson.linkUrl;
    return GGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'g5.school.detail.material'.tr().toUpperCase(),
            style: GText.label.copyWith(color: GColors.link),
          ),
          const SizedBox(height: 10),
          SelectableText(lesson.body, style: GText.body),
          if (link != null) ...[
            const SizedBox(height: 14),
            GButton(
              label: 'g5.school.detail.openLink'.tr(),
              icon: GIcons.arrowUpRight,
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              onPressed: () => unawaited(
                launchUrl(
                  Uri.parse(link),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Uri.parse(link).host,
              textAlign: TextAlign.center,
              style: GText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// "O'qidim": serverga belgilanadi, ro'yxat yangilanadi.
class _ReadButton extends ConsumerStatefulWidget {
  const _ReadButton({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_ReadButton> createState() => _ReadButtonState();
}

class _ReadButtonState extends ConsumerState<_ReadButton> {
  var _busy = false;

  Future<void> _markRead() async {
    setState(() => _busy = true);
    try {
      await ref.read(schoolV5RepositoryProvider).markLessonRead(widget.taskId);
      ref.invalidate(schoolAssignmentsProvider);
    } on SchoolException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('g5.school.detail.readFailed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GButton(
    label: 'g5.school.detail.markRead'.tr(),
    icon: GIcons.checkCircle,
    loading: _busy,
    onPressed: _busy ? null : _markRead,
  );
}
