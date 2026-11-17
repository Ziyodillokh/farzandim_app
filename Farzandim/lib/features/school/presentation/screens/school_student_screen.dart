// ─────────────────────────────────────────────────────────────────────
// SchoolStudentScreen — "Farzandim maktabda"
// ─────────────────────────────────────────────────────────────────────
//
// O'quvchi bo'yicha joriy chorak (yoki o'quv yili) statistikasi: davomat
// halqasi va sinf o'rtachasi (K=5), kelish vaqti va seriya, 8 haftalik
// dinamika, yozma vazifalar va (bola Parvoz Growth'ga bog'langan bo'lsa)
// fanlar bo'yicha natija. Reyting yo'q. Pastda — tezkor amallar.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/growth/presentation/widgets/growth_summary_cards.dart';
import 'package:farzandim/features/iq/presentation/iq_dashboard_card.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_dashboard_card.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/compose_launcher.dart';
import 'package:farzandim/features/school/presentation/widgets/overview_cards.dart';
import 'package:farzandim/features/school/presentation/widgets/overview_header.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Growth natijalari davri (kun).
const int _growthDays = 30;

class SchoolStudentScreen extends ConsumerWidget {
  const SchoolStudentScreen({required this.studentId, super.key});

  final String studentId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(studentOverviewProvider(studentId));
    try {
      await ref
          .read(studentOverviewProvider(studentId).future)
          .timeout(const Duration(seconds: 8));
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(studentOverviewProvider(studentId));
    final body = overview.when(
      loading: () => const SchoolLoadingView(),
      error: (error, _) => SchoolErrorView(
        error: SchoolFailure.fromError(error),
        onRetry: () => ref.invalidate(studentOverviewProvider(studentId)),
      ),
      data: (data) => RefreshIndicator(
        color: SK.blue,
        backgroundColor: SK.card,
        onRefresh: () => _refresh(ref),
        child: _OverviewBody(overview: data, studentId: studentId),
      ),
    );
    return SchoolScaffold(title: 'school.overview.title'.tr(), body: body);
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({required this.overview, required this.studentId});

  final StudentOverview overview;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = overview.student;
    final period = overview.period;
    final childId = ref.watch(
      schoolLinksProvider.select(
        (links) => links.valueOrNull?.students
            .where((s) => s.id == studentId)
            .firstOrNull
            ?.childId,
      ),
    );
    final since = 'school.overview.since'.tr(
      namedArgs: {'date': formatSchoolDay(period.from)},
    );
    final periodLabel = period.isQuarter && period.number != null
        ? 'school.overview.quarter'.tr(namedArgs: {'n': '${period.number}'})
        : '${'school.overview.year'.tr()} · $since';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
      children: [
        OverviewHeaderCard(student: student, periodLabel: periodLabel),
        SkSectionLabel('school.overview.attendance'.tr()),
        OverviewAttendanceCard(attendance: overview.attendance),
        const SizedBox(height: 10),
        OverviewHabitRow(attendance: overview.attendance),
        const SizedBox(height: 10),
        OverviewWeeksCard(weeks: overview.attendance.weeks),
        SkSectionLabel('school.overview.tasks'.tr()),
        OverviewTasksCard(tasks: overview.tasks, today: period.to),
        SkSectionLabel('school.overview.growth'.tr()),
        _GrowthCard(childId: childId),
        SkSectionLabel('school.overview.development'.tr()),
        _DevelopmentSection(childId: childId),
        SkSectionLabel('school.overview.wellbeing'.tr()),
        _WellbeingCard(studentId: studentId),
        SkSectionLabel('school.overview.actions'.tr()),
        _Actions(studentId: studentId),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(SolarIconsBold.shieldCheck, size: 16, color: SK.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'school.overview.privacy'.tr(),
                style: skText(12, c: SK.faint, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Parvoz Growth: fanlar bo'yicha foiz (oxirgi 30 kun).
class _GrowthCard extends ConsumerWidget {
  const _GrowthCard({required this.childId});

  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = this.childId;
    if (childId == null) {
      return _note(
        SolarIconsBold.linkRound,
        'school.overview.growthNotLinked'.tr(),
      );
    }
    final summary = ref.watch(
      growthSummaryProvider((childId: childId, days: _growthDays)),
    );
    return summary.when(
      loading: () => const SkCard(
        child: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(color: SK.blue)),
        ),
      ),
      error: (_, _) =>
          _note(SolarIconsBold.infoCircle, 'school.overview.growthEmpty'.tr()),
      data: (data) {
        if (data == null || !data.hasTests || data.subjects.isEmpty) {
          return _note(
            SolarIconsBold.graphUp,
            'school.overview.growthEmpty'.tr(),
          );
        }
        return _subjects(context, data, childId);
      },
    );
  }

  Widget _subjects(BuildContext context, LearningSummary data, String childId) {
    final subjects = [...data.subjects]
      ..sort((a, b) => b.percent.compareTo(a.percent));
    return SkCard(
      onTap: () => unawaited(context.push(AppRoutes.growthPath(childId))),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'school.overview.growthHint'.tr(),
                  style: skText(12.5, c: SK.dim),
                ),
              ),
              Text(
                'school.overview.growthOpen'.tr(),
                style: skText(12.5, c: SK.sky, w: FontWeight.w600),
              ),
              const Icon(
                SolarIconsOutline.altArrowRight,
                size: 16,
                color: SK.sky,
              ),
            ],
          ),
          for (final s in subjects.take(6)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(growthSubjectIcon(s.subject), size: 18, color: SK.dim),
                const SizedBox(width: 10),
                SizedBox(
                  width: 104,
                  child: Text(
                    s.subject.labelKey.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: skText(13, height: 1.3),
                  ),
                ),
                Expanded(
                  child: SkBar(
                    fraction: s.percent / 100,
                    color: s.percent >= 80
                        ? SK.green
                        : s.percent >= 60
                        ? SK.sky
                        : SK.amber,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${s.percent}%',
                    textAlign: TextAlign.right,
                    style: skText(13, w: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(IconData icon, String text) => SkCard(
    child: Row(
      children: [
        SkIconBubble(icon: icon, color: SK.dim, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: skText(13, c: SK.dim, height: 1.45)),
        ),
      ],
    ),
  );
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget action(
      IconData icon,
      Color color,
      String label,
      VoidCallback onTap,
    ) => SkCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          SkIconBubble(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: skText(14, w: FontWeight.w500)),
          ),
          const Icon(
            SolarIconsOutline.altArrowRight,
            size: 18,
            color: SK.faint,
          ),
        ],
      ),
    );
    return Column(
      children: [
        action(
          SolarIconsBold.chatRoundDots,
          SK.sky,
          'school.overview.writeTeacher'.tr(),
          () => unawaited(
            composeTo(
              context,
              ref,
              studentId: studentId,
              target: ContactTarget.homeroom,
              topic: ContactTopic.progress,
            ),
          ),
        ),
        const SizedBox(height: 8),
        action(
          SolarIconsBold.calendarMark,
          SK.green,
          'school.overview.history'.tr(),
          () => unawaited(
            context.push(AppRoutes.schoolAttendancePath(studentId)),
          ),
        ),
        const SizedBox(height: 8),
        action(
          SolarIconsBold.walking,
          SK.amber,
          'school.overview.earlyExit'.tr(),
          () => unawaited(context.push(AppRoutes.schoolEarlyExits)),
        ),
      ],
    );
  }
}

/// Parvoz testlari: Kelajak (qiziqishlar) va IQ — natija bo'lsa kartalar
/// (dashboard'dagi bilan bir xil); bola ilovasi bog'lanmagan bo'lsa izoh.
class _DevelopmentSection extends StatelessWidget {
  const _DevelopmentSection({required this.childId});

  final String? childId;

  @override
  Widget build(BuildContext context) {
    final childId = this.childId;
    if (childId == null) {
      return SkCard(
        child: Text(
          'school.overview.growthNotLinked'.tr(),
          style: skText(13, c: SK.dim, height: 1.45),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: Text(
            'school.overview.developmentHint'.tr(),
            style: skText(12.5, c: SK.dim, height: 1.4),
          ),
        ),
        KelajakDashboardCard(childId: childId),
        const SizedBox(height: 10),
        IqDashboardCard(childId: childId),
      ],
    );
  }
}

/// Ruhiy holat: maxfiylik izohi va psixologga yozish (natija ko'rinmaydi).
class _WellbeingCard extends ConsumerWidget {
  const _WellbeingCard({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SkCard(
      tint: SK.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkIconBubble(
                icon: SolarIconsBold.lockKeyhole,
                color: SK.green,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'school.overview.wellbeingTitle'.tr(),
                  style: skText(14.5, w: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'school.overview.wellbeingBody'.tr(),
            style: skText(13, c: SK.dim),
          ),
          const SizedBox(height: 14),
          ParvozSecondaryButton(
            label: 'school.overview.writePsychologist'.tr(),
            leading: const Icon(
              SolarIconsBold.handHeart,
              size: 20,
              color: Colors.white,
            ),
            onPressed: () => unawaited(
              composeTo(
                context,
                ref,
                studentId: studentId,
                target: ContactTarget.psychologist,
                topic: ContactTopic.advice,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
