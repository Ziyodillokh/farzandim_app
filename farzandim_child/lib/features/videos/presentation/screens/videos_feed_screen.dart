// ─────────────────────────────────────────────────────────────────────
// VideosFeedScreen — Videolar feed (PDF p5)
// ─────────────────────────────────────────────────────────────────────
//
// Top header → search/filter → tabs → hero card → top videolar
// section → tavsiya etilgan section. Filter va search natijasi
// bo'sh bo'lsa empty state ko'rsatiladi.

import 'package:easy_localization/easy_localization.dart';
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

class VideosFeedScreen extends ConsumerWidget {
  const VideosFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroVideo = ref.watch(heroVideoProvider);
    final topVideos = ref.watch(topVideosProvider);
    final recommended = ref.watch(recommendedVideosProvider);
    final filtered = ref.watch(filteredVideosProvider);

    return Scaffold(
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
              const VideosSearchBar(),
              const VideoTabs(),
              const SizedBox(height: 16),
              Expanded(
                // Pastga torting → yangilash. Admin yangi video (jumladan
                // YouTube havola) qo'shgach, bola ro'yxatni shu yerda darhol
                // yangilaydi (5 daqiqalik keshni e'tiborsiz, fresh fetch).
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(backendVideosProvider);
                    await ref.read(backendVideosProvider.future);
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.18,
                            ),
                            _EmptyState(onClear: () => _clearAll(ref)),
                          ],
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
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
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  void _clearAll(WidgetRef ref) {
    ref.read(videoSearchQueryProvider.notifier).state = '';
    ref.read(videoFilterProvider.notifier).state =
        const VideoFilterState();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // FARO faceSad — qidiruv natija bermadi feel
    return EmptyStateMascot(
      faroVariant: FaroVariant.faceSad,
      title: 'videos.feed.emptyTitle'.tr(),
      subtitle: 'videos.feed.emptyHint'.tr(),
      actionLabel: 'videos.feed.emptyClearButton'.tr(),
      onAction: onClear,
    );
  }
}
