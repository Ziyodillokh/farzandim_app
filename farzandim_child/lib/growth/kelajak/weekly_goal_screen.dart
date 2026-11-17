// K04 · Haftalik maqsad: kichik maqsad (qaysi fan, haftasiga necha marta),
// shu haftadagi natija va ko'rib chiqish sanasi (keyingi dushanba). Ortda
// qolsa — uyaltirmasdan maqsadni kichraytirish taklifi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kelajak/kelajak_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class KelajakWeeklyGoalScreen extends ConsumerStatefulWidget {
  const KelajakWeeklyGoalScreen({super.key, this.suggested});

  /// K03 dan kelgan fan (maqsad shu fan bilan taklif qilinadi).
  final Subject? suggested;

  @override
  ConsumerState<KelajakWeeklyGoalScreen> createState() =>
      _KelajakWeeklyGoalScreenState();
}

class _KelajakWeeklyGoalScreenState
    extends ConsumerState<KelajakWeeklyGoalScreen> {
  /// Tahrirlash: `null` — saqlangan maqsad ko'rsatiladi.
  WeeklyGoal? _draft;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(weeklyGoalProvider).valueOrNull;
    final editing =
        _draft ??
        (saved == null || widget.suggested != null
            ? WeeklyGoal(target: 3, subject: widget.suggested ?? saved?.subject)
            : null);
    final goal = editing ?? saved!;
    final now = ref.watch(learningClockProvider)();
    final done = goalProgress(goal, ref.watch(learningResultsProvider), now);
    final review = weekStartOf(now).add(const Duration(days: 7));
    // Hafta kunlari bo'yicha kutilgan natijadan ortda qolgan bo'lsa.
    final expected = (goal.target * now.weekday / 7).floor();
    final behind = editing == null && done < expected && done < goal.target;
    final grade = ref.watch(learningProfileProvider)?.grade;
    final subjects = [
      for (final s in Subject.values)
        if (grade == null || s.isTaughtIn(grade)) s,
    ];
    final title = _goalTitle(goal);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kelajak.goal.title'.tr(),
        ),
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (editing != null)
              GButton(
                label: 'g5.kelajak.goal.save'.tr(),
                icon: GIcons.check,
                onPressed: () async {
                  await ref.read(weeklyGoalProvider.notifier).save(editing);
                  if (!context.mounted) return;
                  setState(() => _draft = null);
                  if (context.canPop()) context.pop();
                },
              )
            else
              GButton(
                label: 'g5.kelajak.goal.start'.tr(),
                icon: GIcons.play,
                onPressed: () => context.push(
                  goal.subject == null
                      ? GrowthV5Routes.learn
                      : GrowthV5Routes.practice(goal.subject!),
                ),
              ),
          ],
        ),
        children: [
          GGlass(
            glowHue: GHue.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const GTile(icon: GIcons.target, hue: GHue.gold, size: 48),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: GText.h3)),
                  ],
                ),
                const SizedBox(height: 14),
                GProgressBar(
                  value: goal.target == 0
                      ? 0
                      : (done / goal.target).clamp(0, 1).toDouble(),
                  semanticLabel: title,
                ),
                const SizedBox(height: 8),
                Text(
                  'g5.kelajak.goal.done'.tr(
                    namedArgs: {'done': '$done', 'target': '${goal.target}'},
                  ),
                  style: GText.itemTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  'g5.kelajak.goal.review'.tr(
                    namedArgs: {
                      'date': DateFormat(
                        'd-MMMM, EEEE',
                        context.locale.languageCode,
                      ).format(review),
                    },
                  ),
                  style: GText.caption,
                ),
              ],
            ),
          ),
          if (behind)
            GNote(
              text: 'g5.kelajak.goal.behind'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.smiley,
            ),
          if (editing == null)
            Align(
              alignment: Alignment.centerLeft,
              child: GLink(
                label: 'g5.kelajak.goal.change'.tr(),
                onPressed: () => setState(() => _draft = goal),
              ),
            )
          else ...[
            GSection(
              title: 'g5.kelajak.goal.howOften'.tr(),
              child: Row(
                children: [
                  for (var n = 1; n <= kGoalMaxTarget; n++) ...[
                    if (n > 1) const SizedBox(width: 8),
                    Expanded(
                      child: GOption(
                        label: '$n',
                        selected: editing.target == n,
                        showRadio: false,
                        onTap: () => setState(
                          () => _draft = WeeklyGoal(
                            target: n,
                            subject: editing.subject,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GSection(
              title: 'g5.kelajak.goal.subject'.tr(),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Choice(
                    label: 'g5.kelajak.goal.anySubject'.tr(),
                    selected: editing.subject == null,
                    onTap: () => setState(
                      () => _draft = WeeklyGoal(target: editing.target),
                    ),
                  ),
                  for (final s in subjects)
                    _Choice(
                      label: s.label,
                      selected: editing.subject == s,
                      onTap: () => setState(
                        () => _draft = WeeklyGoal(
                          target: editing.target,
                          subject: s,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _goalTitle(WeeklyGoal goal) => goal.subject == null
      ? 'g5.kelajak.goal.anyTitle'.tr(namedArgs: {'count': '${goal.target}'})
      : 'g5.kelajak.goal.subjectTitle'.tr(
          namedArgs: {
            'count': '${goal.target}',
            'subject': goal.subject!.label,
          },
        );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GPressable(
    onTap: onTap,
    selected: selected,
    semanticLabel: label,
    child: GChip(
      label: label,
      kind: selected ? GChipKind.ok : GChipKind.neutral,
      icon: selected ? GIcons.check : null,
    ),
  );
}
