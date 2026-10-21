// ─────────────────────────────────────────────────────────────────────
// IqHubScreen — "IQ test" (`/iq`): qoidalar, boshlash / davom ettirish,
// oxirgi natija va tarix. Yosh kiritilmagan — profilga; 9–20 dan
// tashqarida — izoh. Qayta topshirish sanasi serverdan.
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:farzandim_child/features/iq/presentation/providers/iq_providers.dart';
import 'package:farzandim_child/features/iq/presentation/widgets/iq_result_card.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class IqHubScreen extends ConsumerWidget {
  const IqHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(iqOverviewProvider);
    final overview = state.valueOrNull;
    final level = overview?.age.level;
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              color: HomeColors.primary,
              backgroundColor: HomeColors.card,
              edgeOffset: insets.top,
              onRefresh: () => refreshIq(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  growthTopInset(context),
                  16,
                  insets.bottom + 24,
                ),
                children: [
                  InnerPageHeader(
                    title: 'iq.title'.tr(),
                    subtitle: level == null
                        ? null
                        : 'iq.hub.level'.tr(namedArgs: {'level': '$level'}),
                    fallbackRoute: IqRoutes.home,
                  ),
                  const SizedBox(height: 16),
                  if (overview != null)
                    _HubBody(overview: overview)
                  else if (state.hasError)
                    _Message(
                      text: iqErrorText(
                        state.error is IqException
                            ? (state.error! as IqException).code
                            : IqErrorCode.unknown,
                      ),
                      action: 'common.retry'.tr(),
                      onTap: () => refreshIq(ref),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 96),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: HomeColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({required this.overview});

  final IqOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (overview.age.status) {
      case IqAgeStatus.ageRequired:
        return _Message(
          text: 'iq.hub.ageRequired'.tr(),
          action: 'iq.hub.ageAction'.tr(),
          onTap: () async {
            await context.push(IqRoutes.ageEdit);
            await refreshIq(ref);
          },
        );
      case IqAgeStatus.ageOutOfRange || IqAgeStatus.unknown:
        return _Message(text: 'iq.error.ageOutOfRange'.tr());
      case IqAgeStatus.ok:
        break;
    }
    final last = overview.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Rules(),
        const SizedBox(height: 14),
        _Action(overview: overview),
        if (last != null) ...[
          const SizedBox(height: 18),
          IqResultCard(result: last),
        ],
        if (overview.history.length > 1) ...[
          const SizedBox(height: 18),
          KelajakHeading('iq.hub.history'.tr()),
          const SizedBox(height: 8),
          for (final entry in overview.history) _HistoryRow(entry: entry),
        ],
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    final rules = [
      'iq.hub.rule1',
      'iq.hub.rule2',
      'iq.hub.rule3',
      'iq.hub.rule4',
    ];
    return Container(
      decoration: homeCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('iq.hub.intro'.tr(), style: homeText(14, height: 1.4)),
          const SizedBox(height: 12),
          for (final key in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      SolarIconsBold.checkCircle,
                      size: 16,
                      color: HomeColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      key.tr(),
                      style: homeText(
                        13,
                        color: HomeColors.textDim,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.overview});

  final IqOverview overview;

  @override
  Widget build(BuildContext context) {
    final active = overview.active;
    final next = overview.nextAvailableAt;
    if (active != null) {
      return KelajakPillButton(
        label: 'iq.hub.continue'.tr(
          namedArgs: {'n': '${active.answered}', 'total': '${active.total}'},
        ),
        icon: SolarIconsOutline.arrowRight,
        height: 50,
        onTap: () => openIqTest(context),
      );
    }
    if (overview.canStart) {
      return KelajakPillButton(
        label: 'iq.hub.start'.tr(),
        icon: SolarIconsOutline.arrowRight,
        height: 50,
        onTap: () => openIqTest(context),
      );
    }
    return KelajakNote(
      next == null
          ? 'iq.error.unknown'.tr()
          : 'iq.hub.nextAt'.tr(namedArgs: {'date': iqDate(context, next)}),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final IqHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final r = entry.result;
    final score = r.standardScore;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: homeCardDecoration(radius: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                iqDate(context, r.completedAt),
                style: homeText(13, color: HomeColors.textDim),
              ),
            ),
            Text(
              r.isNormed && score != null ? 'IQ $score' : iqBandLabel(r.band),
              style: homeText(
                13.5,
                weight: FontWeight.w700,
                color: iqBandColor(r.band),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onTap});

  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: homeText(14.5, color: HomeColors.textDim, height: 1.4),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            KelajakPillButton(label: action, onTap: onTap),
          ],
        ],
      ),
    );
  }
}
