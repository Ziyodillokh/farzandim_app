// ─────────────────────────────────────────────────────────────────────
// ProgressScreen — "Rivojlanish" (Growth yangi konsepsiyasi, maket 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Tartib:
//   • Header: "Rivojlanish" + kalendar (kunlik rivojlanish / streak)
//   • Haftalik rivojlanish — umumiy o'sish, natija halqasi, 3 ko'rsatkich
//   • Kuchli fanlar — fanlar bo'yicha foiz + progress
//   • Kelajak profilim — qiziqishlar va kuchli tomonlar (Kelajak mavjud
//     bo'lsa; batafsil — /kelajak/progress)
//   • So'nggi natijalar — oxirgi 3 ta test (barchasi alohida sahifada)
//   • Tavsiya — eng past natijali fandan test ishlash
//
// Ma'lumot `progress_providers.dart`dan (hozircha preview).

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_refresh.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_profile_section.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/providers/progress_providers.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/progress_hero_card.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/progress_section.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/recommendation_card.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/result_row.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/subject_score_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bosh sahifadagi "So'nggi natijalar" ro'yxati uzunligi.
const _recentLimit = 3;

/// Maketdagi bo'limlar orasidagi masofa.
const _sectionGap = 14.0;

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({
    super.key,
    this.navigation = const ChildBottomNavigation(),
  });

  final Widget navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyProgressProvider);
    final scores = ref.watch(subjectScoresProvider);
    final results = ref.watch(recentResultsProvider);
    final tip = ref.watch(progressRecommendationProvider);

    return Scaffold(
      backgroundColor: HomeColors.bg,
      extendBody: true,
      bottomNavigationBar: navigation,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              color: HomeColors.primary,
              backgroundColor: HomeColors.card,
              edgeOffset: insets.top,
              onRefresh: () =>
                  Future.wait([refreshLearning(ref), refreshKelajak(ref)]),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16.5,
                  growthTopInset(context) - 1.8,
                  16.5,
                  insets.bottom + 16,
                ),
                children: [
                  PageHeader(
                    title: 'progress.title'.tr(),
                    titleSize: 32,
                    titleLetterSpacing: -1.1,
                    actions: [
                      HeaderIconButton(
                        semanticLabel: 'progress.calendar'.tr(),
                        onTap: () => context.push(LearningRoutes.calendar),
                        child: const HomeSvgIcon(homeCalendarSvg, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.8),
                  if (weekly == null)
                    const _NoResults()
                  else
                    ProgressHeroCard(progress: weekly),
                  if (scores.isNotEmpty) ...[
                    const SizedBox(height: _sectionGap),
                    ProgressSection(
                      title: 'progress.strongSubjects'.tr(),
                      subtitle: 'progress.strongSubtitle'.tr(),
                      onSeeAll: () => context.push('/progress/subjects'),
                      // Eng yuqori natijali 3 fan.
                      child: StrongSubjectsRow(
                        scores:
                            ([...scores]..sort(
                                  (a, b) => b.percent.compareTo(a.percent),
                                ))
                                .take(3)
                                .toList(),
                      ),
                    ),
                  ],
                  // O'z bo'shlig'i bilan; Kelajak mavjud bo'lmasa — yo'q.
                  const KelajakProfileSection(topGap: _sectionGap),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: _sectionGap),
                    ProgressSection(
                      title: 'progress.recentResults'.tr(),
                      subtitle: 'progress.recentSubtitle'.tr(),
                      onSeeAll: () => context.push('/progress/results'),
                      contentPadding: const EdgeInsets.fromLTRB(6.5, 0, 7, 4.5),
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < math.min(_recentLimit, results.length);
                            i++
                          ) ...[
                            if (i > 0) const SizedBox(height: 3.2),
                            ResultRow(result: results[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (tip != null) ...[
                    const SizedBox(height: _sectionGap),
                    RecommendationCard(recommendation: tip),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: homeCardDecoration(),
      child: Text(
        'progress.noResults'.tr(),
        textAlign: TextAlign.center,
        style: homeText(14, color: HomeColors.textDim),
      ),
    );
  }
}
