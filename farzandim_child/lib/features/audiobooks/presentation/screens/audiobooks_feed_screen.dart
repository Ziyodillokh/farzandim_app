// ─────────────────────────────────────────────────────────────────────
// AudiobooksFeedScreen — Audiokitoblar + Kitoblar (TabBar)
// ─────────────────────────────────────────────────────────────────────
//
// Top header → 2 ta tab (Audiokitoblar / Kitoblar) → mos kontent.
// Sprint 5.x: Books bottom nav'dan olib tashlandi, audiobooks ichida tab.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobook_section.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobooks_search_bar.dart';
import 'package:farzandim_child/features/books/presentation/widgets/books_feed_body.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AudiobooksFeedScreen extends ConsumerWidget {
  const AudiobooksFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: GradientBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DashboardTopHeader(
                    onAvatarTap: () => context.push('/account-edit'),
                  ),
                ),
                const SizedBox(height: 8),
                const _TopTabs(),
                Expanded(
                  child: TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _AudiobooksTab(ref: ref),
                      const BooksFeedBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const ChildBottomNavigation(),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Audiokitoblar'),
          Tab(text: 'Kitoblar'),
        ],
      ),
    );
  }
}

class _AudiobooksTab extends StatelessWidget {
  const _AudiobooksTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final forYou = ref.watch(forYouAudiobooksProvider);
    final mostListened = ref.watch(mostListenedProvider);
    final newest = ref.watch(newestAudiobooksProvider);
    final allFiltered = ref.watch(filteredAudiobooksProvider);

    return Column(
      children: [
        const AudiobooksSearchBar(),
        const SizedBox(height: 8),
        Expanded(
          child: allFiltered.isEmpty
              ? const _EmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      AudiobookSection(
                        title: 'Siz uchun',
                        books: forYou,
                      ),
                      const SizedBox(height: 24),
                      AudiobookSection(
                        title: "Eng ko'p o'qilgan",
                        books: mostListened,
                      ),
                      const SizedBox(height: 24),
                      AudiobookSection(
                        title: "Yangi qo'shilgan",
                        books: newest,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            'Hech narsa topilmadi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
