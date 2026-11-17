// U09 · Urinishlar tarixi (mashq): sana, mavzu, natija va holat; qator bosilsa
// o'sha mashq natijasi (U08). Olimpiada va baholash guruhlari 7-bosqichda
// qo'shiladi — ungacha bo'sh tab ko'rsatilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AttemptsScreen extends ConsumerWidget {
  const AttemptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(storedResultsProvider);
    final items = results.valueOrNull ?? const <TestResult>[];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.attempts.title'.tr(),
          subtitle: 'g5.attempts.subtitle'.tr(),
        ),
        onRefresh: () => refreshLearning(ref),
        children: [
          if (results.isLoading && !results.hasValue)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              ),
            )
          else if (results.hasError && items.isEmpty)
            GNote(
              text: 'g5.common.offline'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => refreshLearning(ref),
              ),
            )
          else if (items.isEmpty)
            GNote(
              text: 'g5.attempts.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.sparkle,
              action: GLink(
                label: 'g5.attempts.startPractice'.tr(),
                onPressed: () => GrowthLinks.learnTab(context),
              ),
            )
          else
            GList(children: [for (final r in items) _Row(result: r)]),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.result});

  final TestResult result;

  @override
  Widget build(BuildContext context) {
    final topic = result.topic.of(context.locale.languageCode).trim();
    final title = topic.isEmpty ? result.subject.label : topic;
    final score = '${result.correct}/${result.total}';
    final date = localizedDayMonth(result.date);
    final daily = result.isDaily;
    final status = daily
        ? 'g5.attempts.confirmed'.tr()
        : 'g5.attempts.extra'.tr();
    final statusColor = daily
        ? const Color(0xFFBFF3DB)
        : const Color(0xFFC9D3EA);
    return GPressable(
      onTap: () => GrowthLinks.result(context, result.id),
      pressedScale: .985,
      semanticLabel: 'g5.attempts.rowA11y'.tr(
        namedArgs: {
          'title': title,
          'score': score,
          'date': date,
          'status': status,
        },
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GSpace.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              subjectTile(result.subject),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: title,
                        children: [
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: score,
                            style: GText.display(
                              13,
                            ).copyWith(color: GColors.textLabel),
                          ),
                        ],
                      ),
                      style: GText.itemTitle,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(date, style: GText.caption),
                        Text('·', style: GText.caption),
                        GIcon(
                          daily ? GIcons.checkCircle : GIcons.sparkle,
                          size: 14,
                          color: statusColor,
                        ),
                        Text(
                          status,
                          style: GText.onest(
                            12.5,
                            weight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
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
      ),
    );
  }
}
