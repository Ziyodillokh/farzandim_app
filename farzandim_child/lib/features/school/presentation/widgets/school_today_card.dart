// Bosh sahifa — "Maktabim" kartasi (faqat maktabga bog'langan bolada):
// maktab, sinf va dars vaqti, bugungi holat belgisi, kelish / ketish vaqti,
// "QR orqali kirish" va yechilmagan psixologik testlar belgisi. Karta
// bosilsa — "Maktabim" sahifasi.
//
// Bog'lanmagan bolada (yoki server funksiyani hali bilmasa) karta ham,
// uning ustidagi bo'shliq ham yo'q — bosh sahifa avvalgidek qoladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/attendance_display.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/attendance_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolTodayCard extends ConsumerWidget {
  const SchoolTodayCard({super.key});

  /// Karta ustidagi bo'shliq (bosh sahifa bo'limlari orasidagidek).
  static const topGap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Yangilanayotganda / oflaynda oxirgi ma'lum holat ko'rinadi.
    final today = ref.watch(schoolTodayProvider).valueOrNull;
    if (today == null) return const SizedBox.shrink();
    final psychCount = ref.watch(psychAssignmentsProvider).valueOrNull?.length;
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: Semantics(
        button: true,
        label: 'school.hub.title'.tr(),
        child: GestureDetector(
          onTap: () => openSchoolHub(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: homeCardDecoration(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardHeader(today: today),
                const SizedBox(height: 10),
                AttendanceTimes(record: today.record),
                if (today.canScan) ...[
                  const SizedBox(height: 10),
                  SchoolScanButton(
                    label: scanLabelKey(today).tr(),
                    onTap: () => openSchoolCheckIn(context),
                  ),
                ],
                if (psychCount != null && psychCount > 0) ...[
                  const SizedBox(height: 10),
                  _PsychBadge(count: psychCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.today});

  final SchoolToday today;

  @override
  Widget build(BuildContext context) {
    final name = today.schoolName.trim();
    final schedule = schoolScheduleLine(today);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SchoolColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            SolarIconsBold.squareAcademicCap,
            size: 22,
            color: SchoolColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'school.hub.title'.tr() : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeText(15.5, weight: FontWeight.w700, height: 1.25),
              ),
              if (schedule != null) ...[
                const SizedBox(height: 2),
                Text(
                  schedule,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(
                    12.5,
                    color: HomeColors.textDim,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        AttendanceStatusChip(kind: attendanceChipOf(today), maxWidth: 130),
      ],
    );
  }
}

/// Yechilmagan psixologik testlar: "Psixologik testlar: 2".
class _PsychBadge extends StatelessWidget {
  const _PsychBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: HomeColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            SolarIconsBold.clipboardList,
            size: 18,
            color: HomeColors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'school.psych.homeBadge'.tr(namedArgs: {'count': '$count'}),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: homeText(13.5, weight: FontWeight.w700, height: 1.25),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: HomeColors.chevron,
          ),
        ],
      ),
    );
  }
}
