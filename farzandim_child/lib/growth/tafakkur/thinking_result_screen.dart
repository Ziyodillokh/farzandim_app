// U16 · Tafakkur topshiriqlari natijasi: to'rt yo'nalish (rasmli
// qonuniyatlar, sonlar, so'zlar, mantiq) bo'yicha so'z bilan baho va
// bittadan amaliy maslahat. IQ ball va yosh me'yori ko'rsatilmaydi (TT G09);
// ma'lumot yetarli bo'lmasa shunday deb yoziladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/providers/iq_providers.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Yo'nalish bahosi (so'z bilan).
enum ThinkingLevel { strong, good, growing, notEnough }

/// Kamida shuncha savol bo'lmasa — «Ma'lumot yetarli emas».
const _minItems = 3;

ThinkingLevel thinkingLevelOf(IqDomainScore? score) {
  if (score == null || score.total < _minItems) return ThinkingLevel.notEnough;
  final ratio = score.right / score.total;
  if (ratio >= .75) return ThinkingLevel.strong;
  if (ratio >= .5) return ThinkingLevel.good;
  return ThinkingLevel.growing;
}

extension on IqItemKind {
  GIconData get icon => switch (this) {
    IqItemKind.figural => GIcons.shapes,
    IqItemKind.numeric => GIcons.mathOperations,
    IqItemKind.verbal => GIcons.textAa,
    IqItemKind.logic => GIcons.puzzlePiece,
  };

  GHue get hue => switch (this) {
    IqItemKind.figural => GHue.blue,
    IqItemKind.numeric => GHue.green,
    IqItemKind.verbal => GHue.rose,
    IqItemKind.logic => GHue.gold,
  };
}

class ThinkingResultScreen extends ConsumerWidget {
  const ThinkingResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(iqOverviewProvider);
    final overview = async.valueOrNull;
    final last = overview?.last;
    final language = context.locale.languageCode;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.thinking.title'.tr(),
        ),
        dock: GButton(
          label: 'g5.thinking.practice'.tr(),
          icon: GIcons.brain,
          // Topshiriqlar mavjud Tafakkur testida (vaqt va davom ettirish shu yerda).
          onPressed: () => context.push('/iq'),
        ),
        children: [
          if (last == null)
            GNote(
              text: async.isLoading
                  ? 'g5.thinking.loading'.tr()
                  : 'g5.thinking.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.brain,
            )
          else ...[
            Text(
              'g5.thinking.first'.tr(
                namedArgs: {
                  'date': DateFormat(
                    'd-MMMM',
                    language,
                  ).format(last.completedAt.toLocal()),
                },
              ),
              style: GText.caption,
            ),
            for (final kind in IqItemKind.values)
              _DomainCard(
                kind: kind,
                level: thinkingLevelOf(
                  last.domains.where((d) => d.kind == kind).firstOrNull,
                ),
              ),
            GNote(
              text: 'g5.thinking.note'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.info,
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: GLink(
              label: 'g5.thinking.history'.tr(),
              onPressed: () => context.push(GrowthV5Routes.attempts),
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.kind, required this.level});

  final IqItemKind kind;
  final ThinkingLevel level;

  @override
  Widget build(BuildContext context) {
    return GGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GTile(icon: kind.icon, hue: kind.hue, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'g5.thinking.domains.${kind.name}'.tr(),
                  style: GText.itemTitle,
                ),
              ),
              GChip(
                label: 'g5.thinking.levels.${level.name}'.tr(),
                kind: switch (level) {
                  ThinkingLevel.strong => GChipKind.ok,
                  ThinkingLevel.good => GChipKind.info,
                  ThinkingLevel.growing => GChipKind.warn,
                  ThinkingLevel.notEnough => GChipKind.neutral,
                },
              ),
            ],
          ),
          if (level != ThinkingLevel.notEnough) ...[
            const SizedBox(height: 8),
            Text('g5.thinking.tips.${kind.name}'.tr(), style: GText.caption),
          ],
        ],
      ),
    );
  }
}
