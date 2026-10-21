// ─────────────────────────────────────────────────────────────────────
// KelajakProgressScreen — "Kelajak profilim" (`/kelajak/progress`)
// ─────────────────────────────────────────────────────────────────────
//
// Mavzular bo'yicha oldingi va oxirgi natija (oddiy chiziqlar), o'sib
// borayotgan qiziqishlar va yechilgan testlar tarixi (sahifalab). Hali
// yakunlangan test bo'lmasa — hub'ga taklif. Pastga tortib yangilanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_refresh.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_results_provider.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_state_views.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/progress/kelajak_progress_widgets.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

const _sectionGap = 22.0;

class KelajakProgressScreen extends ConsumerWidget {
  const KelajakProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kelajakProgressProvider);
    final progress = state.valueOrNull;
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
                    title: 'kelajak.progress.title'.tr(),
                    subtitle: progress == null || progress.isEmpty
                        ? null
                        : 'kelajak.progress.subtitle'.tr(
                            namedArgs: {
                              'count': '${progress.sessionsCompleted}',
                            },
                          ),
                    fallbackRoute: KelajakRoutes.hub,
                  ),
                  const SizedBox(height: 18),
                  if (progress != null)
                    _ProgressBody(progress: progress)
                  else if (state.isLoading)
                    const KelajakLoading()
                  else
                    KelajakErrorView(
                      code: kelajakCodeOf(state.error),
                      onRetry: () => ref.invalidate(kelajakProgressProvider),
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

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.progress});

  final KelajakProgress progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return SchoolMessageView(
        icon: SolarIconsOutline.chartSquare,
        iconColor: HomeColors.blue,
        title: 'kelajak.progress.emptyTitle'.tr(),
        message: 'kelajak.progress.emptyBody'.tr(),
        actionLabel: 'kelajak.progress.toHub'.tr(),
        onAction: () => returnToKelajakHub(context),
      );
    }
    final rising = progress.risingInterests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress.categories.isNotEmpty) ...[
          KelajakHeading(
            'kelajak.progress.topics'.tr(),
            hint: 'kelajak.progress.topicsHint'.tr(),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: homeCardDecoration(radius: 18),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KelajakBarsLegend(),
                for (final c in progress.categories) ...[
                  const SizedBox(height: 16),
                  KelajakCategoryDeltaRow(category: c),
                ],
              ],
            ),
          ),
        ],
        if (rising.isNotEmpty) ...[
          const SizedBox(height: _sectionGap),
          KelajakHeading(
            'kelajak.progress.rising'.tr(),
            hint: 'kelajak.progress.risingHint'.tr(),
          ),
          const SizedBox(height: 12),
          KelajakChipWrap(
            icon: SolarIconsOutline.graphUp,
            labels: [for (final i in rising) i.name.inLocale(context)],
          ),
        ],
        const SizedBox(height: _sectionGap),
        KelajakHeading('kelajak.progress.history'.tr()),
        const SizedBox(height: 12),
        const _History(),
        const SizedBox(height: 18),
        KelajakNote('kelajak.progress.note'.tr()),
      ],
    );
  }
}

/// Yechilgan testlar — sahifalab ("Yana ko'rsatish").
class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kelajakResultsProvider);
    final results = state.valueOrNull;
    if (results == null) {
      if (state.isLoading) return const KelajakLoading(top: 12);
      return _MoreButton(
        label: 'common.retry'.tr(),
        onTap: () => ref.invalidate(kelajakResultsProvider),
      );
    }
    if (results.isEmpty) {
      return KelajakNote('kelajak.progress.historyEmpty'.tr());
    }
    final notifier = ref.read(kelajakResultsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in results.items) ...[
          KelajakHistoryRow(item: item),
          const SizedBox(height: 8),
        ],
        if (results.isLoadingMore)
          const KelajakLoading(top: 8)
        else if (results.hasMore)
          _MoreButton(
            label: results.loadMoreError == null
                ? 'kelajak.progress.more'.tr()
                : 'kelajak.progress.moreFailed'.tr(),
            onTap: notifier.loadMore,
          ),
      ],
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: KelajakPillButton(
        label: label,
        isPrimary: false,
        height: 42,
        onTap: onTap,
      ),
    );
  }
}
