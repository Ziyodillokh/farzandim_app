// B01 pastki kartalari: Maktab (kelish vaqti, topshiriqlar) va Kunning savoli.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayTiles extends ConsumerWidget {
  const TodayTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showQuestion =
        ref.watch(kelajakAvailableProvider) &&
        ref.watch(kelajakOverviewProvider).valueOrNull != null;
    const school = _SchoolTile();
    if (!showQuestion) return school;
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: school),
          SizedBox(width: 12),
          Expanded(child: _QuestionTile()),
        ],
      ),
    );
  }
}

/// Bir xil ko'rinishdagi kichik karta: plita + ↗, sarlavha, holat qatori, chip.
class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.icon,
    required this.hue,
    required this.title,
    required this.status,
    required this.onTap,
    this.statusColor = GColors.textMuted,
    this.statusDot,
    this.chip,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final String status;
  final Color statusColor;
  final Color? statusDot;
  final Widget? chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GPressable(
        onTap: onTap,
        pressedScale: .98,
        child: GGlass(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GTile(icon: icon, hue: hue, size: 40),
                  const Spacer(),
                  const GIcon(
                    GIcons.arrowUpRight,
                    size: 18,
                    color: GColors.chevron,
                    secondaryOpacity: 0,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: GText.onest(15, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusDot != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusDot,
                        boxShadow: [
                          BoxShadow(color: statusDot!, blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      status,
                      style: GText.onest(12.5, color: statusColor),
                    ),
                  ),
                ],
              ),
              if (chip != null) ...[const SizedBox(height: 10), chip!],
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolTile extends ConsumerWidget {
  const _SchoolTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(schoolTodayProvider).valueOrNull;
    void onTap() => GrowthLinks.schoolTab(context);
    if (today == null) {
      // Maktabga ulanmagan: shaxsiy mashq baribir ochiq.
      return _TileCard(
        icon: GIcons.backpack,
        hue: GHue.green,
        title: 'g5.today.school.connect'.tr(),
        status: 'g5.today.school.connectBody'.tr(),
        onTap: onTap,
      );
    }
    final assignments =
        ref.watch(schoolAssignmentsProvider).valueOrNull ?? const [];
    final open = assignments.where((a) => a.isDone != true).length;
    final arrived = today.record?.inAt;
    final status = !today.isSchoolDay
        ? 'g5.today.school.noSchoolDay'.tr()
        : arrived != null
        ? 'g5.today.school.arrived'.tr(namedArgs: {'time': arrived})
        : 'g5.today.school.notMarked'.tr();
    final present =
        arrived != null && today.record?.status != AttendanceStatus.absent;
    return _TileCard(
      icon: GIcons.backpack,
      hue: GHue.green,
      title: 'g5.today.school.title'.tr(),
      status: status,
      statusColor: present ? const Color(0xFFA7EBCB) : GColors.textMuted,
      statusDot: present ? GColors.success : null,
      chip: GChip(
        label: open > 0
            ? 'g5.today.school.tasks'.tr(namedArgs: {'count': '$open'})
            : 'g5.today.school.noTasks'.tr(),
        kind: open > 0 ? GChipKind.info : GChipKind.neutral,
      ),
      onTap: onTap,
    );
  }
}

class _QuestionTile extends ConsumerWidget {
  const _QuestionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(kelajakOverviewProvider).valueOrNull?.daily;
    final state = daily == null ? null : kelajakDayStateOf(daily.today);
    final language = context.locale.languageCode;
    final done = state == KelajakDayState.done;
    return _TileCard(
      icon: GIcons.compass,
      hue: GHue.gold,
      title: 'g5.today.question.title'.tr(),
      status: daily?.title.of(language) ?? '',
      chip: daily == null
          ? null
          : GChip(
              label: done
                  ? 'g5.today.question.done'.tr()
                  : 'g5.today.question.minutes'.tr(
                      namedArgs: {'count': '${daily.estimatedMinutes}'},
                    ),
              kind: done ? GChipKind.ok : GChipKind.warn,
            ),
      onTap: () => GrowthLinks.dailyQuestion(context, daily?.type),
    );
  }
}
