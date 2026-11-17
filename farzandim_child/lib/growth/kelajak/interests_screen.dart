// K01 · Qiziqishlarim: sevimli fanlar (bosilsa belgilanadi), Kelajak
// profilidagi qiziqishlar xaritasi (RIASEC o'lchamlari — faqat yo'nalish,
// test natijasi deb ko'rsatilmaydi), tavsiya etilgan kasb sohasi va alohida
// «Xavfsizlik bilimi». Ishtirok ixtiyoriy.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kelajak/kelajak_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class KelajakInterestsScreen extends ConsumerWidget {
  const KelajakInterestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = context.locale.languageCode;
    final grade = ref.watch(learningProfileProvider)?.grade;
    final favorites = ref.watch(favoriteSubjectsProvider).valueOrNull ?? {};
    final overview = ref.watch(kelajakOverviewProvider).valueOrNull;
    final profile = overview?.profile;
    final interests = profile?.interests;
    final safetyDone = ref.watch(safetyProgressProvider).valueOrNull ?? {};
    final career = CareerField.recommended(interests?.top ?? const []);
    final subjects = [
      for (final s in Subject.values)
        if (grade == null || s.isTaughtIn(grade)) s,
    ];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kelajak.interests.title'.tr(),
        ),
        children: [
          GSection(
            title: 'g5.kelajak.interests.subjects'.tr(),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  _SubjectChip(
                    subject: s,
                    selected: favorites.contains(s),
                    onTap: () =>
                        ref.read(favoriteSubjectsProvider.notifier).toggle(s),
                  ),
              ],
            ),
          ),
          GSection(
            title: 'g5.kelajak.interests.map'.tr(),
            actionLabel: 'g5.kelajak.interests.refresh'.tr(),
            onAction: () =>
                GrowthLinks.dailyQuestion(context, overview?.daily?.type),
            child: GGlass(
              child: interests == null || interests.dimensions.isEmpty
                  ? Text(
                      'g5.kelajak.interests.mapEmpty'.tr(),
                      style: GText.body,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final d in interests.dimensions) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.name.of(language),
                                  style: GText.itemTitle,
                                ),
                              ),
                              Text('${d.score}', style: GText.caption),
                            ],
                          ),
                          const SizedBox(height: 6),
                          GProgressBar(
                            value: d.score / 100,
                            semanticLabel: d.name.of(language),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'g5.kelajak.interests.answered'.tr(
                            namedArgs: {
                              'count': '${profile?.answeredQuestions ?? 0}',
                            },
                          ),
                          style: GText.caption,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'g5.kelajak.interests.note'.tr(),
                          style: GText.caption,
                        ),
                      ],
                    ),
            ),
          ),
          GList(
            children: [
              GListItem(
                leading: GTile(icon: career.icon, hue: career.hue, size: 44),
                title: 'g5.kelajak.interests.careers'.tr(),
                subtitle: 'g5.kelajak.interests.recommended'.tr(
                  namedArgs: {'field': '${career.key}.title'.tr()},
                ),
                onTap: () => context.push(GrowthV5Routes.kelajakCareers),
              ),
              GListItem(
                leading: const GTile(
                  icon: GIcons.shieldCheck,
                  hue: GHue.teal,
                  size: 44,
                ),
                title: 'g5.kelajak.safety.title'.tr(),
                subtitle: 'g5.kelajak.safety.progress'.tr(
                  namedArgs: {
                    'done': '${safetyDone.length}',
                    'total': '${SafetyLesson.values.length}',
                  },
                ),
                onTap: () => context.push(GrowthV5Routes.kelajakSafety),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  final Subject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: subject.label,
      child: GChip(
        label: subject.label,
        kind: selected ? GChipKind.ok : GChipKind.neutral,
        icon: selected ? GIcons.check : subject.gIcon,
      ),
    );
  }
}
