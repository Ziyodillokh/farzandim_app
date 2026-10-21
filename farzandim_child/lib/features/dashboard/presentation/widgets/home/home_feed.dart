// Bosh sahifa ("Asosiy") bo'limlari — maketdagi tartibda:
// header → stat kartalar → (Maktabim) → Bugungi testlar → (Kelajagim) →
// So‘nggi natijalar → Kutubxona. "Maktabim" kartasi faqat maktabga bog'langan
// bolada, "Kelajagim" — Kelajak mavjud bo'lsa (kunlik savollar holati).
//
// Kutubxona butun kenglikda (lenta ekran chetigacha), qolganlari 16pt
// ichkarida. Ekran (`ChildDashboardScreen`) faqat aylantirish, yangilash
// va bannerlar bilan shug'ullanadi.

import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_stat_cards.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/library_section.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/recent_results_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/today_tests_card.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_today_card.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_today_card.dart';
import 'package:flutter/material.dart';

/// Bosh sahifa qobig'i — fon, pull-to-refresh, aylantirish, suzuvchi nav.
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({
    super.key,
    required this.onRefresh,
    this.banners = const [],
    this.navigation = const ChildBottomNavigation(),
  });

  final Future<void> Function() onRefresh;

  /// Yuqoridagi xizmat bannerlari (yangilanish, iOS sozlash).
  final List<Widget> banners;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      extendBody: true,
      bottomNavigationBar: navigation,
      // Builder — Scaffold ichidagi MediaQuery: `extendBody` tufayli pastki
      // padding nav + mini-pleyer balandligini o'z ichiga oladi (pleyer
      // chiqqanda kontent uning ostida qolib ketmaydi).
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              color: HomeColors.primary,
              backgroundColor: HomeColors.card,
              edgeOffset: insets.top,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  // Maketda header status-bar zonasiga yaqinroq turadi (−3pt) va
                  // header tugmalarining 44pt bosish maydoni uchun yana −3pt.
                  top: growthTopInset(context),
                  bottom: insets.bottom + 16,
                ),
                children: [
                  for (final banner in banners) _Padded(banner),
                  const HomeFeed(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomeFeed extends StatelessWidget {
  const HomeFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Padded(HomeHeader()),
        SizedBox(height: 5),
        _Padded(HomeStatCards()),
        // O'z bo'shlig'i bilan; bog'lanmagan bolada balandligi 0.
        _Padded(SchoolTodayCard()),
        SizedBox(height: 8),
        _Padded(TodayTestsCard()),
        // O'z bo'shlig'i bilan; Kelajak mavjud bo'lmasa balandligi 0.
        _Padded(KelajakTodayCard()),
        SizedBox(height: 10),
        _Padded(RecentResultsCard()),
        SizedBox(height: 9),
        LibrarySection(),
      ],
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: homePagePadding),
      child: child,
    );
  }
}
