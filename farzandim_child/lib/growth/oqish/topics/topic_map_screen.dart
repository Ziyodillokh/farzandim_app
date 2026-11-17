// U02 · Fanning bilim xaritasi: mavzular egri yo'l bo'ylab — o'zlashtirilgan,
// mashq kerak, hali baholanmagan; joriy mavzu katta ko'k tugun. Sinfdagi o'rin
// yoki reyting ko'rsatilmaydi. Katalog yo'q bo'lsa — aralash mashq taklifi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_path.dart';
import 'package:farzandim_child/growth/oqish/topics/topics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TopicMapScreen extends ConsumerWidget {
  const TopicMapScreen({super.key, required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(subjectTopicMapProvider(subject));
    final data = map.valueOrNull;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: subject.label,
          subtitle: data == null || data.isEmpty
              ? null
              : 'g5.topics.subtitle'.tr(
                  namedArgs: {
                    'grade': '${data.grade}',
                    'count': '${data.topics.length}',
                  },
                ),
        ),
        onRefresh: () => ref.refresh(subjectTopicMapProvider(subject).future),
        children: [
          GSection(
            title: 'g5.topics.mapTitle'.tr(),
            actionLabel: 'g5.topics.attempts'.tr(),
            onAction: () => GrowthLinks.attempts(context),
            child: switch (map) {
              AsyncData(:final value) when value.isEmpty => _Empty(
                subject: subject,
              ),
              AsyncData(:final value) => TopicPath(
                map: value,
                onOpen: (topic) =>
                    GrowthLinks.topic(context, subject, topic.id),
                labelOf: (topic) => _Label(
                  topic: topic,
                  isCurrent: topic.id == value.currentTopicId,
                ),
              ),
              AsyncError() => GNote(
                text: 'g5.topics.loadError'.tr(),
                kind: GNoteKind.warn,
                icon: GIcons.wifiSlash,
                action: GLink(
                  label: 'g5.common.retry'.tr(),
                  onPressed: () =>
                      ref.invalidate(subjectTopicMapProvider(subject)),
                ),
              ),
              _ => Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'g5.common.loading'.tr(),
                  textAlign: TextAlign.center,
                  style: GText.caption,
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return GGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              subjectTile(subject, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text('g5.topics.emptyTitle'.tr(), style: GText.h3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('g5.topics.emptyBody'.tr(), style: GText.body),
          const SizedBox(height: 14),
          GButton(
            label: 'g5.topics.mixedPractice'.tr(),
            size: GButtonSize.md,
            trailingIcon: GIcons.arrowRight,
            onPressed: () => GrowthLinks.practice(context, subject),
          ),
        ],
      ),
    );
  }
}

/// Tugun yonidagi matn: nom (joriy bo'lsa belgi), holat va sana/topshiriqlar.
class _Label extends StatelessWidget {
  const _Label({required this.topic, required this.isCurrent});

  final LearningTopic topic;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final (statusText, statusIcon, statusColor) = !topic.available
        ? (
            'g5.topics.soon'.tr(),
            GIcons.hourglassMedium,
            const Color(0xFFB4C0DA),
          )
        : switch (topic.mastery) {
            TopicMastery.mastered => (
              'g5.topics.mastered'.tr(),
              GIcons.sealCheck,
              const Color(0xFF8BE8C0),
            ),
            TopicMastery.practice => (
              'g5.topics.practice'.tr(),
              GIcons.arrowsClockwise,
              const Color(0xFFFFD27A),
            ),
            TopicMastery.notAssessed => (
              'g5.topics.notAssessed'.tr(),
              GIcons.circleDashed,
              const Color(0xFFB4C0DA),
            ),
          };
    final assessed = topic.lastAssessedAt;
    final meta = topic.completedAttempts <= 0
        ? null
        : assessed != null
        ? 'g5.topics.meta'.tr(
            namedArgs: {
              'date': localizedDayMonth(assessed),
              'count': '${topic.completedAttempts}',
            },
          )
        : 'g5.topics.metaCount'.tr(
            namedArgs: {'count': '${topic.completedAttempts}'},
          );
    final dimmed = topic.mastery == TopicMastery.notAssessed && !isCurrent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              topic.title.of(language),
              style: GText.onest(
                14.5,
                weight: FontWeight.w700,
                color: dimmed ? GColors.textLabel : GColors.text,
                height: 1.3,
              ),
            ),
            if (isCurrent)
              GChip(label: 'g5.topics.current'.tr(), kind: GChipKind.info),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GIcon(statusIcon, size: 15, color: statusColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                statusText,
                style: GText.onest(
                  12.5,
                  weight: FontWeight.w600,
                  color: statusColor,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (meta != null) ...[
          const SizedBox(height: 2),
          Text(
            meta,
            style: GText.onest(12, color: GColors.textMuted, height: 1.35),
          ),
        ],
      ],
    );
  }
}
