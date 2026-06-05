// ─────────────────────────────────────────────────────────────────────
// ContentHubScreen — Videolar + Audiokitoblar + Kitoblar birlashmasi
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanuvchi talabiga ko'ra videolar, audiokitoblar va kitoblar
// bo'limlari pastki nav'da bitta tab ostida birlashtirildi. Bu yerda
// 3 ta TopTab (Videolar / Audiokitoblar / Kitoblar) bilan yagona hub.
// Konkurslar alohida bo'lim sifatida saqlandi (boshqa tab).
//
// Eski /videos, /audiobooks, /books route'lari saqlanadi (deep-link
// uchun), lekin bottom nav endi /content ga olib boradi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobook_section.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobooks_search_bar.dart';
import 'package:farzandim_child/features/books/presentation/widgets/books_feed_body.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/videos/data/models/filter_state.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/hero_video_card.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_section.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_tabs.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/videos_search_bar.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContentHubScreen extends ConsumerWidget {
  const ContentHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
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
                      const _VideosTab(),
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

// ─── Top tabs (3 ta) ─────────────────────────────────────────────────
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
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Videolar'),
          Tab(text: 'Audiokitoblar'),
          Tab(text: 'Kitoblar'),
        ],
      ),
    );
  }
}

// ─── Videos tab (videos_feed_screen body) ─────────────────────────────
class _VideosTab extends ConsumerWidget {
  const _VideosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroVideo = ref.watch(heroVideoProvider);
    final topVideos = ref.watch(topVideosProvider);
    final recommended = ref.watch(recommendedVideosProvider);
    final filtered = ref.watch(filteredVideosProvider);

    return Column(
      children: [
        const VideosSearchBar(),
        const VideoTabs(),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? EmptyStateMascot(
                  faroVariant: FaroVariant.faceSad,
                  title: 'videos.feed.emptyTitle'.tr(),
                  subtitle: 'videos.feed.emptyHint'.tr(),
                  actionLabel: 'videos.feed.emptyClearButton'.tr(),
                  onAction: () {
                    ref.read(videoSearchQueryProvider.notifier).state = '';
                    ref.read(videoFilterProvider.notifier).state =
                        const VideoFilterState();
                  },
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (heroVideo != null) ...[
                        HeroVideoCard(video: heroVideo),
                        const SizedBox(height: 24),
                      ],
                      if (topVideos.isNotEmpty) ...[
                        VideoSection(
                          title: 'videos.feed.topVideos'.tr(),
                          videos: topVideos,
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (recommended.isNotEmpty)
                        VideoSection(
                          title: 'videos.feed.recommended'.tr(),
                          videos: recommended,
                          onViewAll: () {},
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Audiobooks tab (audiobooks_feed_screen mantiq qaytarildi) ────────
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
              ? _emptyAudiobooks()
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      AudiobookSection(title: 'Siz uchun', books: forYou),
                      const SizedBox(height: 24),
                      AudiobookSection(
                          title: "Eng ko'p o'qilgan", books: mostListened),
                      const SizedBox(height: 24),
                      AudiobookSection(
                          title: "Yangi qo'shilgan", books: newest),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyAudiobooks() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.headphones, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            "Audiokitoblar topilmadi",
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
