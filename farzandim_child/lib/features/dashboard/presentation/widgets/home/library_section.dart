// "Kutubxona" — video darslar va audiokitoblar bitta lentada (REAL kontent).
//
// Bo'lim butun ekran kengligida chiziladi: karta foni 16pt ichkarida,
// gorizontal lenta esa ekran chetigacha (maketdagidek) suriladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/saved_audiobooks_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/library_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/recent_results_card.dart';
import 'package:farzandim_child/features/videos/presentation/providers/video_engagement_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lentadagi maksimal kartalar soni.
const _maxItems = 8;

/// Sahifa gorizontal chekkasi (karta foni shu qadar ichkarida).
const homePagePadding = 16.0;

class LibrarySection extends ConsumerWidget {
  const LibrarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _buildItems(context, ref);
    return Stack(
      children: [
        Positioned.fill(
          left: homePagePadding,
          right: homePagePadding,
          child: DecoratedBox(decoration: homeCardDecoration()),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => context.push('/content'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: homePagePadding + 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeSectionTitle(
                        title: 'home.library'.tr(),
                        titleSize: 20.5,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'home.librarySubtitle'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(13.5, color: HomeColors.textDim),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              if (items.isEmpty)
                const _LibraryEmpty()
              else
                _LibraryStrip(items: items),
            ],
          ),
        ),
      ],
    );
  }

  /// Video va audiokitoblar navbatma-navbat (V, A, V, A …).
  List<LibraryItem> _buildItems(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(topVideosProvider);
    final books = ref.watch(newestAudiobooksProvider);
    final favoriteVideos = ref.watch(favoriteVideoIdsProvider);
    final savedBooks = ref.watch(savedAudiobookIdsProvider);

    final videoItems = [
      for (final v in videos)
        LibraryItem(
          id: 'v:${v.id}',
          kind: LibraryKind.video,
          title: v.title,
          subtitle: v.category.trim().isNotEmpty
              ? v.category.trim()
              : 'Parvoz Growth',
          imageUrl: v.thumbnailUrl,
          fallbackColor: v.thumbnailColor,
          reward: v.xpReward,
          saved: favoriteVideos.contains(v.id),
          onTap: () => context.push('/video-player', extra: v),
          onToggleSave: () => _toggle(
            context,
            ref.read(favoriteVideoIdsProvider.notifier).toggle(v.id),
          ),
        ),
    ];
    final bookItems = [
      for (final b in books)
        LibraryItem(
          id: 'a:${b.id}',
          kind: LibraryKind.audiobook,
          title: b.title,
          subtitle: b.author,
          imageUrl: b.coverUrl,
          fallbackColor: b.coverColor,
          reward: b.xpReward,
          saved: savedBooks.contains(b.id),
          onTap: () => ref.read(audioPlayerProvider.notifier).play(b),
          onToggleSave: () => _toggle(
            context,
            ref.read(savedAudiobookIdsProvider.notifier).toggle(b.id),
          ),
        ),
    ];

    final result = <LibraryItem>[];
    for (var i = 0; i < videoItems.length || i < bookItems.length; i++) {
      if (i < videoItems.length) result.add(videoItems[i]);
      if (i < bookItems.length) result.add(bookItems[i]);
    }
    return result.take(_maxItems).toList();
  }

  Future<void> _toggle(BuildContext context, Future<bool> toggled) async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final added = await toggled;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text((added ? 'home.saved' : 'home.unsaved').tr()),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Kartalar lentasi — katta karta ICHIDA qoladi (chetidan chiqmaydi):
/// 3 ta karta to'liq sig'adigan kenglikda, ko'prog'i karta ichida suriladi.
class _LibraryStrip extends StatelessWidget {
  const _LibraryStrip({required this.items});

  final List<LibraryItem> items;

  static const _inset = 9.0;
  static const _gap = 9.0;
  static const _visible = 3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Karta chegarasi (1pt) ichida kesiladi.
      padding: const EdgeInsets.symmetric(horizontal: homePagePadding + 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth =
              (constraints.maxWidth - _inset * 2 - _gap * (_visible - 1)) /
              _visible;
          return SizedBox(
            height: LibraryCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _inset),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (_, i) =>
                  LibraryCard(item: items[i], width: cardWidth),
            ),
          );
        },
      ),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        homePagePadding + 14,
        4,
        homePagePadding + 14,
        8,
      ),
      child: Text(
        'home.libraryEmpty'.tr(),
        style: homeText(13.5, color: HomeColors.textDim),
      ),
    );
  }
}
