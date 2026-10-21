// ─────────────────────────────────────────────────────────────────────
// KelajakHubScreen — "Kelajagim" (`/kelajak`)
// ─────────────────────────────────────────────────────────────────────
//
// Yosh holati (sarlavha ostida), bugungi testlar (holati, savollar soni va
// taxminiy vaqt), savollar mavzulari va "Kelajak profilim"ga havola. Yosh
// kiritilmagan bo'lsa — profilga yo'naltirish (yosh taxmin qilinmaydi),
// oraliqdan tashqarida — tushuntirish. Pastga tortib yangilanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_refresh.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_state_views.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_test_card.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakHubScreen extends ConsumerWidget {
  const KelajakHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kelajakOverviewProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum holat ko'rinadi.
    final overview = state.valueOrNull;
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
              onRefresh: () => refreshKelajak(ref),
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
                    title: 'kelajak.title'.tr(),
                    subtitle: overview == null
                        ? null
                        : kelajakAgeLine(overview.age),
                    fallbackRoute: KelajakRoutes.home,
                  ),
                  const SizedBox(height: 16),
                  if (overview != null)
                    _HubBody(overview: overview)
                  else
                    _HubStatus(state: state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.overview});

  final KelajakOverview overview;

  @override
  Widget build(BuildContext context) {
    switch (overview.age.status) {
      case KelajakAgeStatus.ageRequired:
        return const KelajakAgeRequiredView();
      case KelajakAgeStatus.ageOutOfRange || KelajakAgeStatus.unknown:
        return const KelajakOutOfRangeView();
      case KelajakAgeStatus.ok:
        break;
    }
    final categories = [
      for (final c in overview.categories) c.name.inLocale(context),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KelajakNote('kelajak.hub.intro'.tr()),
        const SizedBox(height: 18),
        KelajakHeading('kelajak.hub.tests'.tr()),
        const SizedBox(height: 10),
        if (overview.tests.isEmpty)
          KelajakNote('kelajak.hub.empty'.tr())
        else
          for (final test in overview.tests) ...[
            KelajakTestCard(
              test: test,
              onTap: () => openKelajakSession(context, test.type),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 4),
        _ProfileLink(overview: overview),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 22),
          KelajakHeading(
            'kelajak.hub.topics'.tr(),
            hint: 'kelajak.hub.topicsHint'.tr(),
          ),
          const SizedBox(height: 12),
          KelajakChipWrap(labels: categories),
        ],
      ],
    );
  }
}

/// "Kelajak profilim" — rivojlanish sahifasiga havola.
class _ProfileLink extends StatelessWidget {
  const _ProfileLink({required this.overview});

  final KelajakOverview overview;

  @override
  Widget build(BuildContext context) {
    final profile = overview.profile;
    final subtitle = profile == null || profile.availableQuestions == 0
        ? 'kelajak.hub.profileBody'.tr()
        : 'kelajak.hub.profileAnswered'.tr(
            namedArgs: {
              'answered': '${profile.answeredQuestions}',
              'total': '${profile.availableQuestions}',
            },
          );
    return Semantics(
      button: true,
      label: 'kelajak.progress.title'.tr(),
      child: GestureDetector(
        onTap: () => openKelajakProgress(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: homeCardDecoration(radius: 18),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              const KelajakIconSquare(icon: SolarIconsBold.graphUp),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'kelajak.progress.title'.tr(),
                      style: homeText(15.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: homeText(
                        12.5,
                        color: HomeColors.textDim,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: HomeColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overview hali yo'q: yuklanmoqda, xato yoki Kelajak serverda yo'q.
class _HubStatus extends ConsumerWidget {
  const _HubStatus({required this.state});

  final AsyncValue<KelajakOverview?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) return const KelajakLoading();
    final error = state.error;
    return KelajakErrorView(
      code: error == null ? KelajakErrorCode.unavailable : kelajakCodeOf(error),
      onRetry: () => ref.invalidate(kelajakOverviewByAccountProvider),
    );
  }
}
