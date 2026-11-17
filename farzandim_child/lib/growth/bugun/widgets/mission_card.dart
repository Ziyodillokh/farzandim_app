// B01 «Bugungi vazifa» kartasi: halqa (bajarilgan fanlar), fanlar qatori va
// navbatdagi fanni boshlash tugmasi. Holatlar: profil yo'q (birinchi kirish),
// yuklanmoqda, xato, hammasi bajarilgan.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/learning_rules.dart';
import 'package:farzandim_child/growth/common/plan_row.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissionCard extends ConsumerWidget {
  const MissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(needsLearningSetupProvider)) return const _SetupMission();
    final profile = ref.watch(savedLearningProfileProvider);
    final plan = ref.watch(dailyPlanProvider);
    if (plan.isEmpty) {
      if (profile.hasError) {
        return _ErrorMission(onRetry: () => refreshLearning(ref));
      }
      return const _LoadingMission();
    }
    return _PlanMission(plan: plan);
  }
}

class _PlanMission extends StatelessWidget {
  const _PlanMission({required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context) {
    final next = plan.nextItem;
    final remaining = plan.items.where((i) => !i.isDone).toList();
    final don = remaining.fold<int>(
      0,
      (sum, i) => sum + maxDonFor(i.questionCount),
    );
    return GGlass(
      kind: GGlassKind.feat,
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ProgressRing(done: plan.doneCount, total: plan.items.length),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'g5.today.mission.label'.tr().toUpperCase(),
                      style: GText.label.copyWith(color: GColors.link),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      next == null
                          ? 'g5.today.mission.done'.tr()
                          : 'g5.today.mission.remaining'.tr(
                              namedArgs: {'count': '${remaining.length}'},
                            ),
                      style: GText.display(19).copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    if (next == null)
                      Text(
                        'g5.today.mission.doneBody'.tr(),
                        style: GText.onest(13, color: GColors.textLabel),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'g5.today.mission.minutes'.tr(
                              namedArgs: {
                                'count':
                                    '${remaining.length * kMinutesPerSubject}',
                              },
                            ),
                            style: GText.onest(13, color: GColors.textLabel),
                          ),
                          if (don > 0)
                            GChip(
                              label: 'g5.today.mission.donUpTo'.tr(
                                namedArgs: {'count': '$don'},
                              ),
                              kind: GChipKind.warn,
                              icon: GIcons.coin,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in plan.items) ...[
            PlanRow(item: item, isNext: identical(item, next)),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 10),
          if (next != null)
            GButton(
              label: 'g5.today.mission.startSubject'.tr(
                namedArgs: {'subject': next.subject.label},
              ),
              trailingIcon: GIcons.arrowRight,
              size: GButtonSize.md,
              onPressed: () => GrowthLinks.practice(context, next.subject),
            )
          else
            GButton(
              label: 'g5.today.mission.practiceMore'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.md,
              onPressed: () => GrowthLinks.learnTab(context),
            ),
        ],
      ),
    );
  }
}

/// Bajarilgan fanlar halqasi (84px), markazda «1/3 fan».
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'g5.today.mission.ringA11y'.tr(
        namedArgs: {'done': '$done', 'total': '$total'},
      ),
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 84,
          child: CustomPaint(
            painter: GProgressRingPainter(total == 0 ? 0 : done / total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$done/$total',
                    style: GText.display(20).copyWith(height: 1.1),
                  ),
                  Text(
                    'g5.today.mission.ringUnit'.tr(),
                    style: GText.onest(
                      11,
                      weight: FontWeight.w600,
                      color: GColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Birinchi kirish: fanlar hali tanlanmagan — «Bugungi 15 daqiqa» taklifi.
class _SetupMission extends StatelessWidget {
  const _SetupMission();

  @override
  Widget build(BuildContext context) {
    return GGlass(
      kind: GGlassKind.feat,
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GTile(icon: GIcons.sparkle, hue: GHue.sky, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'g5.today.mission.setupTitle'.tr(),
                  style: GText.display(19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('g5.today.mission.setupBody'.tr(), style: GText.body),
          const SizedBox(height: 14),
          GButton(
            label: 'g5.today.mission.setupCta'.tr(),
            trailingIcon: GIcons.arrowRight,
            size: GButtonSize.md,
            onPressed: () => GrowthLinks.learningSetup(context),
          ),
        ],
      ),
    );
  }
}

class _LoadingMission extends StatelessWidget {
  const _LoadingMission();

  @override
  Widget build(BuildContext context) {
    return GGlass(
      kind: GGlassKind.feat,
      radius: 28,
      child: SizedBox(
        height: 120,
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: Text('g5.common.loading'.tr(), style: GText.caption),
          ),
        ),
      ),
    );
  }
}

class _ErrorMission extends StatelessWidget {
  const _ErrorMission({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return GNote(
      text: 'g5.today.mission.error'.tr(),
      kind: GNoteKind.warn,
      icon: GIcons.wifiSlash,
      action: GLink(label: 'g5.common.retry'.tr(), onPressed: onRetry),
    );
  }
}
