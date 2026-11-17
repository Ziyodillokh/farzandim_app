// U03 · Mavzu va mashq rejasi: o'quv maqsadi, 10 ta savol (~5 daqiqa), oldingi
// natija, «Bugungi 15 daqiqa» rejasi. Tugallanmagan urinish bo'lsa «Davom
// ettirish (4/10)» — qaytadan boshlanmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/learning_rules.dart';
import 'package:farzandim_child/growth/common/plan_row.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:farzandim_child/growth/oqish/topics/topics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bitta mavzu bo'yicha mashq savollari soni (server qoidasi).
const kTopicQuestions = 10;

class TopicScreen extends ConsumerWidget {
  const TopicScreen({super.key, required this.subject, required this.topicId});

  final Subject subject;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ref.watch(topicProvider(topicId));
    final language = context.locale.languageCode;
    final data = topic.valueOrNull;
    final back = GTopBar.back(
      label: 'g5.common.back'.tr(),
      onPressed: () => context.pop(),
    );
    final grade = ref.watch(learningProfileProvider)?.grade;
    final top = GTopBar(
      leading: back,
      title: data?.title.of(language) ?? subject.label,
      subtitle: grade == null
          ? subject.label
          : '${subject.label} · $grade-sinf',
    );
    final Widget? dock = data == null || !data.available
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GButton(
                label: switch (data.inProgress) {
                  final p? => 'g5.topics.continue'.tr(
                    namedArgs: {
                      'answered': '${p.answered}',
                      'total': '${p.total}',
                    },
                  ),
                  null => 'g5.topics.start'.tr(),
                },
                trailingIcon: GIcons.arrowRight,
                onPressed: () =>
                    GrowthLinks.topicPractice(context, subject, topicId),
              ),
              const SizedBox(height: 10),
              GButton(
                label: 'g5.topics.later'.tr(),
                kind: GButtonKind.ghost,
                size: GButtonSize.second,
                onPressed: () => context.pop(),
              ),
            ],
          );
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: top,
        dock: dock,
        onRefresh: () => ref.refresh(topicProvider(topicId).future),
        children: switch (topic) {
          AsyncData(value: null) => [
            GNote(text: 'g5.topics.notFound'.tr(), kind: GNoteKind.warn),
          ],
          AsyncData(:final value?) => [
            _GoalCard(subject: subject, topic: value),
            if (!value.available)
              GNote(
                text: 'g5.topics.notAvailable'.tr(),
                icon: GIcons.hourglassMedium,
              ),
            _TodayPlan(subject: subject, topic: value),
            GNote(text: 'g5.topics.note'.tr(), kind: GNoteKind.plain),
          ],
          AsyncError() => [
            GNote(
              text: 'g5.topics.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(topicProvider(topicId)),
              ),
            ),
          ],
          _ => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              ),
            ),
          ],
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.subject, required this.topic});

  final Subject subject;
  final LearningTopic topic;

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final goal = topic.goal?.of(language);
    final last = topic.lastResult;
    return GGlass(
      kind: GGlassKind.feat,
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              subjectTile(subject, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'g5.topics.goalLabel'.tr().toUpperCase(),
                      style: GText.label.copyWith(color: GColors.link),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      goal == null || goal.isEmpty
                          ? topic.title.of(language)
                          : goal,
                      style: GText.h3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _Fact(
                icon: GIcons.listNumbers,
                text: 'g5.topics.questions'.tr(
                  namedArgs: {'count': '$kTopicQuestions'},
                ),
              ),
              _Fact(
                icon: GIcons.timer,
                text: 'g5.topics.minutes'.tr(
                  namedArgs: {'count': '$kMinutesPerSubject'},
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0x12FFFFFF)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'g5.topics.previous'.tr(),
                  style: GText.onest(
                    13,
                    weight: FontWeight.w600,
                    color: GColors.textMuted,
                  ),
                ),
              ),
              GChip(
                icon: GIcons.clockCounterClockwise,
                label: last == null
                    ? 'g5.topics.noPrevious'.tr()
                    : 'g5.topics.previousValue'.tr(
                        namedArgs: {
                          'correct': '${last.correct}',
                          'total': '${last.total}',
                          'date': localizedDayMonth(last.completedAt),
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final GIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GIcon(icon, size: 18, color: GColors.link),
        const SizedBox(width: 8),
        Text(
          text,
          style: GText.onest(
            14,
            weight: FontWeight.w600,
            color: GColors.textBody,
          ),
        ),
      ],
    );
  }
}

/// «Bugungi 15 daqiqa»: kunlik reja; shu fan qatorida — yangi mavzu va takror.
class _TodayPlan extends ConsumerWidget {
  const _TodayPlan({required this.subject, required this.topic});

  final Subject subject;
  final LearningTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(dailyPlanProvider);
    if (plan.isEmpty) return const SizedBox.shrink();
    final language = context.locale.languageCode;
    final map = ref.watch(subjectTopicMapProvider(subject)).valueOrNull;
    final review = map?.topics
        .where(
          (t) =>
              t.id != topic.id &&
              t.mastery == TopicMastery.practice &&
              t.available,
        )
        .firstOrNull;
    final next = plan.nextItem;
    return GSection(
      title: 'g5.topics.todayPlan'.tr(),
      trailing: Text(
        'g5.topics.planDone'.tr(
          namedArgs: {
            'done': '${plan.doneCount}',
            'total': '${plan.items.length}',
          },
        ),
        style: GText.onest(
          12.5,
          weight: FontWeight.w600,
          color: GColors.textMuted,
        ),
      ),
      child: GGlass(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (final item in plan.items) ...[
              PlanRow(
                item: item,
                isNext: identical(item, next),
                lines: item.subject == subject && !item.isDone
                    ? [
                        'g5.topics.newTopic'.tr(
                          namedArgs: {'topic': topic.title.of(language)},
                        ),
                        if (review != null)
                          'g5.topics.reviewTopic'.tr(
                            namedArgs: {'topic': review.title.of(language)},
                          ),
                      ]
                    : null,
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
