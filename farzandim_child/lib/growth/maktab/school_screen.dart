// M01 · Maktab: tasdiqlangan maktab va sinf, bugungi davomat, eng yaqin
// vazifa, jadval (hozir/keyingi), e'lonlar va ikki alohida eshik — anonim
// so'rov va psixologdan shaxsiy yordam. Boshqa o'quvchi ma'lumoti yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:farzandim_child/growth/kirish/link_screens.dart';
import 'package:farzandim_child/growth/maktab/widgets/school_link_state_card.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_models.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SchoolScreen extends ConsumerWidget {
  const SchoolScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(linkStatusProvider)
      ..invalidate(schoolTodayProvider)
      ..invalidate(schoolAssignmentsProvider)
      ..invalidate(schoolNoticesProvider)
      ..invalidate(schoolTimetableProvider)
      ..invalidate(schoolAttendanceMonthProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(schoolTodayProvider);
    final today = todayAsync.valueOrNull;
    if (today == null) {
      return GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(title: 'g5.school.title'.tr()),
        onRefresh: () => _refresh(ref),
        children: [
          if (todayAsync.isLoading)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else
            const SchoolLinkStateCard(),
        ],
      );
    }
    final className = today.className;
    return GScreen(
      theme: GBgTheme.teal,
      top: GTopBar(
        title: 'g5.school.title'.tr(),
        subtitle: className == null
            ? today.schoolName
            : '${today.schoolName} · $className',
        actions: [
          GChip(
            label: 'g5.school.confirmedChip'.tr(),
            kind: GChipKind.ok,
            icon: GIcons.sealCheck,
          ),
        ],
      ),
      onRefresh: () => _refresh(ref),
      children: [
        _AttendanceCard(today: today),
        const _TasksCard(),
        const _TimetableCard(),
        const _NoticesCard(),
        Row(
          children: [
            Expanded(
              child: _Door(
                icon: GIcons.chatCircleText,
                hue: GHue.teal,
                title: 'g5.school.voice'.tr(),
                body: 'g5.school.voiceBody'.tr(),
                onTap: () => GrowthLinks.studentVoice(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Door(
                icon: GIcons.handHeart,
                hue: GHue.sky,
                title: 'g5.school.psychologist'.tr(),
                body: 'g5.school.psychologistBody'.tr(),
                onTap: () => GrowthLinks.psychologist(context),
              ),
            ),
          ],
        ),
        Center(
          child: GLink(
            label: 'g5.school.linkStatus'.tr(),
            icon: GIcons.info,
            onPressed: () => context.push(
              Uri(
                path: GrowthV5Routes.kirishStatus,
                queryParameters: const {kirishFromParam: kirishFromMaktab},
              ).toString(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard({required this.today});

  final SchoolToday today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final month = ref
        .watch(schoolAttendanceMonthProvider(DateTime(now.year, now.month)))
        .valueOrNull;
    final day = month?.dayOf(now);
    final record = today.record;
    final source = record == null ? '' : attendanceSourceLine(record.source);
    return _Pressable(
      onTap: () => GrowthLinks.attendance(context),
      child: GGlass(
        kind: GGlassKind.feat,
        glowHue: GHue.green,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const GTile(icon: GIcons.doorOpen, hue: GHue.green, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attendanceLine(today), style: GText.h3),
                  if (source.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(source, style: GText.caption),
                  ],
                  if (record != null) ...[
                    const SizedBox(height: 8),
                    day?.confirmed == true
                        ? GChip(
                            label: 'g5.school.dayConfirmed'.tr(),
                            kind: GChipKind.ok,
                            icon: GIcons.sealCheck,
                          )
                        : GChip(
                            label: 'g5.school.dayNotConfirmed'.tr(),
                            kind: GChipKind.warn,
                            icon: GIcons.hourglassMedium,
                          ),
                  ],
                ],
              ),
            ),
            const GIcon(
              GIcons.caretRight,
              size: 18,
              color: GColors.chevron,
              secondaryOpacity: 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksCard extends ConsumerWidget {
  const _TasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final tasks = ref.watch(schoolAssignmentsProvider).valueOrNull ?? const [];
    final pending = tasks.where((t) => !taskFinished(t)).toList()
      ..sort(
        (a, b) => (a.dueDate ?? DateTime(2100)).compareTo(
          b.dueDate ?? DateTime(2100),
        ),
      );
    final nearest = pending.firstOrNull;
    return _EntryCard(
      label: 'g5.school.tasks'.tr(),
      onTap: () => GrowthLinks.schoolTasks(context),
      child: nearest == null
          ? Text('g5.school.noTasks'.tr(), style: GText.caption)
          : Row(
              children: [
                taskTile(nearest),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(taskTitle(nearest), style: GText.itemTitle),
                      const SizedBox(height: 2),
                      Text(taskKindLine(nearest), style: GText.caption),
                    ],
                  ),
                ),
                if (nearest.dueDate != null)
                  GChip(
                    label: nearest.isOverdue
                        ? 'g5.school.due.overdue'.tr()
                        : dueLabel(nearest.dueDate, now),
                    kind: nearest.isOverdue ? GChipKind.sos : GChipKind.warn,
                  ),
              ],
            ),
    );
  }
}

class _TimetableCard extends ConsumerWidget {
  const _TimetableCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final day = ref.watch(schoolTimetableProvider(dateOnly(now))).valueOrNull;
    Widget body;
    if (day == null) {
      body = Text(
        'g5.school.timetableScreen.notPublished'.tr(),
        style: GText.caption,
      );
    } else if (day.dayOff != null || day.lessons.isEmpty) {
      body = Text(
        day.published
            ? 'g5.school.noSchoolDay'.tr()
            : 'g5.school.timetableScreen.notPublished'.tr(),
        style: GText.caption,
      );
    } else {
      final lessons = currentLessons(day, now);
      final current = lessons.now;
      final next = lessons.next;
      body = current == null && next == null
          ? Text('g5.school.lessonsOver'.tr(), style: GText.caption)
          : Row(
              children: [
                if (current != null)
                  Expanded(
                    child: _LessonSlot(
                      label: 'g5.school.now'.tr(),
                      lesson: current,
                      on: true,
                    ),
                  ),
                if (current != null && next != null) const SizedBox(width: 10),
                if (next != null)
                  Expanded(
                    child: _LessonSlot(
                      label: 'g5.school.next'.tr(),
                      lesson: next,
                      on: false,
                    ),
                  ),
              ],
            );
    }
    return _EntryCard(
      label: 'g5.school.timetable'.tr(),
      onTap: () => GrowthLinks.timetable(context),
      child: body,
    );
  }
}

class _LessonSlot extends StatelessWidget {
  const _LessonSlot({
    required this.label,
    required this.lesson,
    required this.on,
  });

  final String label;
  final TimetableLesson lesson;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: on ? const Color(0x1A4F86FF) : const Color(0x0AFFFFFF),
        border: Border.all(
          color: on ? const Color(0x528CB4FF) : const Color(0x14FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(lesson.start, style: GText.display(13)),
              const Spacer(),
              Text(
                label.toUpperCase(),
                style: GText.label.copyWith(
                  color: on ? GColors.link : GColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lessonSubjectLabel(lesson.subject),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GText.itemTitle,
          ),
        ],
      ),
    );
  }
}

class _NoticesCard extends ConsumerWidget {
  const _NoticesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(schoolNoticesProvider).valueOrNull;
    final latest = page?.items.firstOrNull;
    final unread = page?.unreadCount ?? 0;
    return _EntryCard(
      label: 'g5.school.announcements'.tr(),
      trailing: unread > 0
          ? GChip(
              label: 'g5.school.newCount'.tr(namedArgs: {'count': '$unread'}),
              kind: GChipKind.info,
            )
          : null,
      onTap: () => GrowthLinks.notices(context),
      child: latest == null
          ? Text('g5.school.noNew'.tr(), style: GText.caption)
          : Row(
              children: [
                const GTile(
                  icon: GIcons.megaphoneSimple,
                  hue: GHue.sky,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GText.itemTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          latest.authorName,
                          if (latest.authorRole.isNotEmpty)
                            'g5.school.announcementsScreen.role.${latest.authorRole}'
                                .tr(),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: GText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Bo'lim kartasi: kichik sarlavha + ↗ va ichidagi mazmun.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.label,
    required this.child,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: GGlass(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label.toUpperCase(), style: GText.label)),
                if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
                const GIcon(
                  GIcons.caretRight,
                  size: 18,
                  color: GColors.chevron,
                  secondaryOpacity: 0,
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.icon,
    required this.hue,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: GGlass(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GTile(icon: icon, hue: hue, size: 40),
            const SizedBox(height: 10),
            Text(title, style: GText.itemTitle),
            const SizedBox(height: 2),
            Text(body, style: GText.caption),
          ],
        ),
      ),
    );
  }
}

class _Pressable extends StatelessWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GPressable(onTap: onTap, pressedScale: .98, child: child),
  );
}
