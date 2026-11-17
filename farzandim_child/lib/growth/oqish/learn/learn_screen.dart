// U01 · O'qish markazi: tugallanmagan mashq (yoki bugungi mashq), 6 ta fan
// (har biri o'z bilim xaritasini ochadi; «Barcha fanlar» — sinfdagi hammasi),
// tafakkur va olimpiada yo'llari. Kutubxona va oflayn to'plam kartalari
// egasining qarori bilan vaqtincha yashirilgan (`_kShowLibraryAndOffline`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/bugun/widgets/mission_card.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/oqish/learn/subject_lists.dart';
import 'package:farzandim_child/growth/oqish/practice/unfinished_practice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(learningProfileProvider);
    return GScreen(
      top: GTopBar(
        title: 'g5.learn.title'.tr(),
        subtitle: profile == null
            ? null
            : 'g5.learn.subtitle'.tr(
                namedArgs: {
                  'grade': '${profile.grade}',
                  'count': '${profile.subjects.length}',
                },
              ),
      ),
      onRefresh: () => refreshLearning(ref),
      children: [
        if (profile == null) const MissionCard() else const _ContinueCard(),
        if (profile != null) _SubjectsSection(profile: profile),
        const _Paths(),
      ],
    );
  }
}

/// Tugallanmagan mashq bo'lsa — «Davom ettirish», bo'lmasa navbatdagi kunlik fan.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = practiceDayKey(ref.watch(learningClockProvider)());
    final unfinished = ref.watch(unfinishedPracticeProvider).valueOrNull;
    final plan = ref.watch(dailyPlanProvider);
    if (unfinished != null && unfinished.day == today) {
      final subject = unfinished.subject;
      final title = unfinished.topic.isEmpty
          ? subject.label
          : '${subject.label} · ${unfinished.topic}';
      return _Card(
        label: 'g5.learn.continueLabel'.tr(),
        title: title,
        subjectTile: subjectTile(subject, size: 48),
        trailing: Text.rich(
          TextSpan(
            text: '${unfinished.answered}',
            children: [
              TextSpan(
                text: '/${unfinished.total}',
                style: GText.onest(13, color: GColors.textMuted),
              ),
            ],
          ),
          style: GText.display(17),
        ),
        progress: GSegments(
          semanticLabel: 'g5.learn.progressA11y'.tr(
            namedArgs: {
              'answered': '${unfinished.answered}',
              'total': '${unfinished.total}',
            },
          ),
          states: [
            for (var i = 0; i < unfinished.total; i++)
              switch (i < unfinished.outcomes.length
                  ? unfinished.outcomes[i]
                  : null) {
                true => GSegmentState.ok,
                false => GSegmentState.warn,
                null =>
                  i == unfinished.answered
                      ? GSegmentState.now
                      : GSegmentState.empty,
              },
          ],
        ),
        cta: 'g5.learn.continueCta'.tr(),
        onTap: () => GrowthLinks.practice(context, subject),
      );
    }
    final next = plan.nextItem;
    if (next == null) return const SizedBox.shrink();
    return _Card(
      label: 'g5.learn.todayLabel'.tr(),
      title: next.subject.label,
      subjectTile: subjectTile(next.subject, size: 48),
      trailing: Text(
        'g5.today.mission.rowQuestions'.tr(
          namedArgs: {'count': '${next.questionCount}'},
        ),
        style: GText.onest(
          13,
          weight: FontWeight.w600,
          color: GColors.textMuted,
        ),
      ),
      cta: 'g5.learn.todayCta'.tr(),
      onTap: () => GrowthLinks.practice(context, next.subject),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.title,
    required this.subjectTile,
    required this.trailing,
    required this.cta,
    required this.onTap,
    this.progress,
  });

  final String label;
  final String title;
  final Widget subjectTile;
  final Widget trailing;
  final Widget? progress;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GGlass(
      kind: GGlassKind.feat,
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              subjectTile,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GText.label.copyWith(color: GColors.link),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(title, style: GText.h3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
          if (progress != null) ...[const SizedBox(height: 12), progress!],
          const SizedBox(height: 12),
          GButton(
            label: cta,
            trailingIcon: GIcons.arrowRight,
            size: GButtonSize.md,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _SubjectsSection extends StatelessWidget {
  const _SubjectsSection({required this.profile});

  final LearningProfile profile;

  @override
  Widget build(BuildContext context) {
    final subjects = featuredSubjects(profile);
    return GSection(
      title: 'g5.learn.subjects'.tr(),
      actionLabel: 'g5.learn.allSubjects'.tr(),
      onAction: () => GrowthLinks.allSubjects(context),
      child: GGlass(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            const gap = 4.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final subject in subjects)
                  SizedBox(
                    width: width,
                    child: GPressable(
                      onTap: () => GrowthLinks.subjectMap(context, subject),
                      semanticLabel: 'g5.learn.knowledgeMapA11y'.tr(
                        namedArgs: {'subject': subject.label},
                      ),
                      pressedScale: .95,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 80),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              subjectTile(subject, size: 44),
                              const SizedBox(height: 8),
                              Text(
                                subject.label,
                                textAlign: TextAlign.center,
                                style: GText.onest(
                                  14.5,
                                  weight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kutubxona va oflayn to'plam kartalari — vaqtincha yashirin (egasi,
/// 2026-11-07). Ekranlar va marshrutlar joyida; qaytarish uchun `true`.
const _kShowLibraryAndOffline = false;

class _Paths extends StatelessWidget {
  const _Paths();

  @override
  Widget build(BuildContext context) {
    final thinking = _PathCard(
      icon: GIcons.brain,
      hue: GHue.gold,
      title: 'g5.learn.thinking'.tr(),
      body: 'g5.learn.thinkingBody'.tr(),
      onTap: () => GrowthLinks.thinking(context),
    );
    final olympiad = _PathCard(
      icon: GIcons.trophy,
      hue: GHue.orange,
      title: 'g5.learn.olympiad'.tr(),
      body: 'g5.learn.olympiadBody'.tr(),
      onTap: () => GrowthLinks.olympiads(context),
    );
    if (!_kShowLibraryAndOffline) return _pair(thinking, olympiad);
    return Column(
      children: [
        _pair(
          _PathCard(
            icon: GIcons.books,
            hue: GHue.sky,
            title: 'g5.learn.library'.tr(),
            body: 'g5.learn.libraryBody'.tr(),
            onTap: () => GrowthLinks.library(context),
          ),
          olympiad,
        ),
        const SizedBox(height: 12),
        _pair(
          thinking,
          _PathCard(
            icon: GIcons.downloadSimple,
            hue: GHue.sky,
            title: 'g5.learn.offline'.tr(),
            body: 'g5.learn.offlineBody'.tr(),
            onTap: () => GrowthLinks.offline(context),
          ),
        ),
      ],
    );
  }

  Widget _pair(Widget left, Widget right) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    ),
  );
}

class _PathCard extends StatelessWidget {
  const _PathCard({
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
              Text(
                title,
                style: GText.onest(15, weight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: GText.onest(
                  12.5,
                  color: GColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
