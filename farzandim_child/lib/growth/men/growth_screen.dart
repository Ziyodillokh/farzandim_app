// I02 · Shaxsiy o'sish: bola faqat o'zining oldingi haftasi bilan
// solishtiriladi — mashg'ulotlar, daqiqalar va seriya. Birinchi haftada
// taqqoslash o'rniga «boshlang'ich nuqta». Boshqa bolalar yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:farzandim_child/growth/men/data/men_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MeGrowthScreen extends ConsumerWidget {
  const MeGrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyActivityProvider);
    final weekly = async.valueOrNull;
    final current = weekly?.current;
    final previous = weekly?.previous;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.green,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.growth.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(weeklyActivityProvider),
        children: [
          if (async.isLoading && weekly == null)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (current == null)
            GNote(
              text: 'g5.men.growth.noData'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.chartLineUp,
            )
          else if (weekly!.firstWeek || previous == null) ...[
            GGlass(
              kind: GGlassKind.feat,
              glowHue: GHue.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GTile(icon: GIcons.flag, hue: GHue.green, size: 48),
                  const SizedBox(height: 12),
                  Text('g5.men.growth.firstWeek'.tr(), style: GText.h3),
                  const SizedBox(height: 4),
                  Text(
                    'g5.men.growth.firstWeekBody'.tr(),
                    style: GText.caption,
                  ),
                ],
              ),
            ),
            _Compare(previous: null, current: current),
          ] else
            _Compare(previous: previous, current: current),
          GList(
            children: [
              GListItem(
                leading: const GTile(
                  icon: GIcons.target,
                  hue: GHue.slate,
                  size: 40,
                ),
                title: 'g5.men.growth.weeklyGoal'.tr(),
                subtitle: 'g5.men.growth.goalSoon'.tr(),
              ),
              GListItem(
                leading: const GTile(
                  icon: GIcons.coins,
                  hue: GHue.gold,
                  size: 40,
                ),
                title: 'g5.men.growth.donHistory'.tr(),
                onTap: () => GrowthLinks.meDon(context),
              ),
              GListItem(
                leading: const GTile(
                  icon: GIcons.clockCounterClockwise,
                  hue: GHue.blue,
                  size: 40,
                ),
                title: 'g5.men.growth.attempts'.tr(),
                onTap: () => GrowthLinks.attempts(context),
              ),
            ],
          ),
          GNote(
            text:
                '${'g5.men.growth.onlyYou'.tr()} ${'g5.men.growth.streakRule'.tr()}',
            kind: GNoteKind.plain,
          ),
        ],
      ),
    );
  }
}

/// «Avvalgi hafta → Bu hafta» uch ko'rsatkichi.
class _Compare extends StatelessWidget {
  const _Compare({required this.previous, required this.current});

  final WeekActivity? previous;
  final WeekActivity current;

  @override
  Widget build(BuildContext context) {
    String days(int n) => 'g5.men.growth.days'.tr(namedArgs: {'n': '$n'});
    final rows = [
      (
        GIcons.checkCircle,
        GHue.blue,
        'g5.men.growth.sessions'.tr(),
        previous == null ? null : '${previous!.sessions}',
        '${current.sessions}',
        previous == null ? 0 : current.sessions - previous!.sessions,
      ),
      (
        GIcons.timer,
        GHue.sky,
        'g5.men.growth.minutes'.tr(),
        previous == null ? null : '${previous!.minutes}',
        '${current.minutes}',
        previous == null ? 0 : current.minutes - previous!.minutes,
      ),
      (
        GIcons.fire,
        GHue.orange,
        'g5.men.growth.streak'.tr(),
        previous == null ? null : days(previous!.streak),
        days(current.streak),
        previous == null ? 0 : current.streak - previous!.streak,
      ),
    ];
    return GGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 52),
              Expanded(
                child: Text(
                  previous == null ? '' : 'g5.men.growth.previous'.tr(),
                  style: GText.label,
                ),
              ),
              Expanded(
                child: Text(
                  'g5.men.growth.current'.tr(),
                  textAlign: TextAlign.end,
                  style: GText.label.copyWith(color: GColors.link),
                ),
              ),
            ],
          ),
          for (final (icon, hue, label, before, now, delta) in rows) ...[
            const SizedBox(height: 12),
            MergeSemantics(
              child: Row(
                children: [
                  GTile(icon: icon, hue: hue, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: GText.caption),
                        if (before != null)
                          Text(
                            before,
                            style: GText.onest(
                              15,
                              weight: FontWeight.w600,
                              color: GColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (before != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: GIcon(
                        GIcons.arrowRight,
                        size: 16,
                        color: GColors.textFaint,
                      ),
                    ),
                  Text(now, style: GText.display(18)),
                  if (delta > 0) ...[
                    const SizedBox(width: 6),
                    GChip(label: '+$delta', kind: GChipKind.ok),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
