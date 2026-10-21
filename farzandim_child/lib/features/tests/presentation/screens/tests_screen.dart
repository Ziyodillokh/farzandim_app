// ─────────────────────────────────────────────────────────────────────
// TestsScreen — "Testlar" (Growth yangi konsepsiyasi, maket 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Tartib:
//   • Header: "Testlar" + qidiruv + ♡ (sevimli testlar)
//   • "Bugungi testlar" hero — kunlik reja (preview) + illyustratsiya
//   • "Kelajagim" qatori — Kelajak testlari hub'i (mavjud bo'lsa)
//   • "So‘nggi natijalar" qatori — o'rtacha natija (preview)
//   • "Fanlar bo‘yicha" — HAQIQIY backend testlari fan bo'yicha
//   • "Yangi testlar" — so'nggi testlar ro'yxati (bosilsa test ochiladi)
//
// Pastga tortilsa testlar qayta yuklanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_refresh.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_tests_entry.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/latest_tests_section.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/results_summary_row.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/subject_grid.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/tests_hero_card.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class TestsScreen extends ConsumerWidget {
  const TestsScreen({
    super.key,
    this.navigation = const ChildBottomNavigation(),
  });

  final Widget navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onRefresh: () async {
                ref.invalidate(backendContestsProvider);
                await Future.wait([
                  ref.read(backendContestsProvider.future),
                  refreshLearning(ref),
                  refreshKelajak(ref),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: growthTopInset(context),
                  bottom: insets.bottom + 16,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PageHeader(
                      title: 'nav.quizzes'.tr(),
                      titleSize: 30,
                      actions: [
                        HeaderIconButton(
                          semanticLabel: 'tests.searchLabel'.tr(),
                          onTap: () => context.push('/tests/search'),
                          child: const HomeSvgIcon(homeSearchSvg, size: 21),
                        ),
                        HeaderIconButton(
                          semanticLabel: 'tests.favorites'.tr(),
                          onTap: () => context.push('/liked-tests'),
                          child: const Icon(
                            SolarIconsBold.heart,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13),
                    child: TestsHeroCard(),
                  ),
                  // O'z bo'shlig'i bilan; Kelajak mavjud bo'lmasa balandligi 0.
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13),
                    child: KelajakTestsEntry(),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: ResultsSummaryRow(),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.5),
                    child: Text(
                      'tests.bySubjects'.tr(),
                      style: homeDisplay(20.5, letterSpacing: -0.3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SubjectGrid(),
                  ),
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: LatestTestsSection(),
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
