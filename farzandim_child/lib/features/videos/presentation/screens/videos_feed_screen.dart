// ─────────────────────────────────────────────────────────────────────
// VideosFeedScreen — "Videolar" (Parvoz dark redizayn, Figma "Videolar")
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilishi:
//   • Header: "Videolar" (Unbounded, katta) + ⟲ tarix + ♡ yoqtirilgan
//     (dumaloq shisha tugmalar → alohida sahifalar)
//   • Kategoriya chip qatori — "Barchasi" + videolardagi janrlar (category).
//     Nofaol chiplar ota-ona "secondary shisha" uslubida (frost + rim).
//   • Vertikal feed — umumiy VideoFeedCard (thumbnail + play + janr•ko'rishlar)
//
// Kartani bosib turish → yoqtirilganlarga qo'shadi. Video ochilganda tarixga
// yoziladi (/video-player). Ikkalasi backend + lokal (video_engagement_*).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/video_engagement_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_ui.dart';
import 'package:farzandim_child/shared/widgets/parvoz_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bola videolar feed ekrani — "Videolar".
class VideosFeedScreen extends ConsumerWidget {
  /// `VideosFeedScreen` konstruktor.
  const VideosFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVideos = ref.watch(backendVideosProvider);
    final feed = ref.watch(videoFeedProvider);
    final categories = ref.watch(videoCategoriesProvider);
    final searching = ref.watch(videoFeedSearchProvider).trim().isNotEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Cache ham, network ham hali kelmagan — skeleton. Aks holda feed/empty.
    final loading = asyncVideos.isLoading && !asyncVideos.hasValue;

    final Widget content;
    if (loading) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 120 + bottomInset),
        children: const [
          _SkeletonCard(),
          SizedBox(height: 22),
          _SkeletonCard(),
          SizedBox(height: 22),
          _SkeletonCard(),
        ],
      );
    } else if (feed.isEmpty) {
      // Qidiruvda natija yo'q → "topilmadi"; aks holda umuman video yo'q.
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + bottomInset),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          if (searching)
            const _NoSearchResults()
          else
            _EmptyState(onRefresh: () => ref.invalidate(backendVideosProvider)),
        ],
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 120 + bottomInset),
        itemCount: feed.length,
        separatorBuilder: (_, __) => const SizedBox(height: 22),
        itemBuilder: (_, i) => _FeedVideoCard(video: feed[i]),
      );
    }

    return Scaffold(
      backgroundColor: vBg,
      extendBody: true,
      bottomNavigationBar: const ChildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header status-bardan biroz pastroqda (sal pastga tushirilgan).
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _VideosHeader(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ParvozSearchField(
                queryProvider: videoFeedSearchProvider,
                hintText: 'videos.feed.searchHint'.tr(),
                accent: vBlue,
              ),
            ),
            const SizedBox(height: 14),
            // Qidiruv paytida kategoriya chiplari yashiriladi (qidiruv barcha
            // videolardan qidiradi, kategoriya e'tiborsiz).
            if (!searching && categories.isNotEmpty) ...[
              _CategoryChips(categories: categories),
              const SizedBox(height: 14),
            ],
            Expanded(
              // Pastga torting → yangilash (admin yangi video qo'shsa darhol).
              child: RefreshIndicator(
                color: vBlue,
                backgroundColor: vVideoBg,
                onRefresh: () async {
                  ref.invalidate(backendVideosProvider);
                  await ref.read(backendVideosProvider.future);
                },
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Header: "Videolar" + tarix + yoqtirilgan ════════════

class _VideosHeader extends StatelessWidget {
  const _VideosHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // FittedBox — katta OS shrift-masshtabida ham kesilmasdan kichrayadi.
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'videos.feed.headerTitle'.tr(),
                maxLines: 1,
                style: vUnb(28, w: FontWeight.w600, ls: -0.84),
              ),
            ),
          ),
        ),
        _CircleIconButton(
          icon: Icons.history_rounded,
          onTap: () => context.push('/watch-history'),
        ),
        const SizedBox(width: 12),
        _CircleIconButton(
          icon: Icons.favorite_border_rounded,
          onTap: () => context.push('/liked-videos'),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: vGlass, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

// ════════════ Kategoriya chiplari (secondary shisha) ════════════

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Highlight uchun EFFECTIVE tanlov (yo'qolgan janr → Barchasi yonadi).
    final selected = ref.watch(effectiveVideoCategoryProvider);
    // Katta shrift-masshtabda ham matn kesilmasin — qator balandligi shrift
    // bilan birga o'sadi (chip matni 14*scale, qator 40*scale > matn qatori).
    final ts = MediaQuery.textScalerOf(context);
    final rowH = ts.scale(40).clamp(40.0, 88.0);

    void select(String? cat) {
      HapticFeedback.selectionClick();
      ref.read(videoCategoryProvider.notifier).state = cat;
    }

    return SizedBox(
      height: rowH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _Chip(
              label: 'videos.feed.categoryAll'.tr(),
              active: selected == null,
              showClose: false,
              onTap: () => select(null),
            );
          }
          final cat = categories[i - 1];
          final active = selected == cat;
          return _Chip(
            label: cat,
            active: active,
            showClose: active,
            onTap: () => select(active ? null : cat),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.showClose,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool showClose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: vPop(
            14,
            w: active ? FontWeight.w600 : FontWeight.w500,
            c: active ? Colors.white : Colors.white.withValues(alpha: 0.85),
          ),
        ),
        if (showClose) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ],
    );

    if (active) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: vBlue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: content,
        ),
      );
    }

    // Nofaol — ota-ona "secondary shisha": oq gradient + rim. Chip qatori solid
    // fon ustida (scroll kontenti ortida emas), shuning uchun BackdropFilter
    // ko'rinmas frost berib behuda saveLayer sarflardi — gradient+rim aynan shu
    // premium shisha ko'rinishini beradi.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.white.withValues(alpha: 0.11),
              Colors.white.withValues(alpha: 0.025),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.2,
          ),
        ),
        child: content,
      ),
    );
  }
}

// ════════════ Feed kartasi — umumiy VideoFeedCard + long-press toggle ════════

class _FeedVideoCard extends ConsumerWidget {
  const _FeedVideoCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteVideoIdsProvider).contains(video.id);
    return VideoFeedCard(
      video: video,
      isFavorite: isFav,
      onTap: () => context.push('/video-player', extra: video),
      // Bosib turish → yoqtirilganlarga qo'shadi/olib tashlaydi.
      onLongPress: () async {
        final added = await ref
            .read(favoriteVideoIdsProvider.notifier)
            .toggle(video.id);
        await HapticFeedback.mediumImpact();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: vVideoBg,
              duration: const Duration(milliseconds: 1400),
              content: Text(
                added
                    ? 'Yoqtirilganlarga qo\'shildi'
                    : 'Yoqtirilganlardan olib tashlandi',
                style: vPop(13, w: FontWeight.w500),
              ),
            ),
          );
      },
    );
  }
}

// ════════════ Skeleton (yuklanish) ════════════

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: vGlass,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: vGlass,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    decoration: BoxDecoration(
                      color: vGlass,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: 140,
                    decoration: BoxDecoration(
                      color: vGlass,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════ Bo'sh holat ════════════

/// Parvoz uslubidagi bo'sh-holat belgisi — shisha doirada ko'k ikon
/// (robot maskot foydalanuvchi so'roviga ko'ra olib tashlangan).
class _EmptyBadge extends StatelessWidget {
  const _EmptyBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x24FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: vBlue.withValues(alpha: 0.25),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 42, color: vBlue),
    );
  }
}

// Qidiruv natijasi bo'sh — "topilmadi" holati.
class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const _EmptyBadge(icon: SolarIconsOutline.magnifierZoomOut),
          const SizedBox(height: 20),
          Text(
            'Hech narsa topilmadi',
            textAlign: TextAlign.center,
            style: vUnb(18, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            "Boshqa so'z bilan qidirib ko'ring",
            textAlign: TextAlign.center,
            style: vPop(14, c: vDim),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const _EmptyBadge(icon: SolarIconsOutline.play),
          const SizedBox(height: 20),
          Text(
            'videos.feed.noVideosTitle'.tr(),
            textAlign: TextAlign.center,
            style: vUnb(18, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'videos.feed.noVideosSubtitle'.tr(),
            textAlign: TextAlign.center,
            style: vPop(14, c: vDim),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onRefresh,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: vBlue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'videos.feed.refresh'.tr(),
                style: vPop(14, w: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
