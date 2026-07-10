// ─────────────────────────────────────────────────────────────────────
// VideosFeedScreen — "Videolar" (Parvoz dark redizayn, Figma "Videolar")
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilishi:
//   • Header: "Videolar" (Unbounded) + ⟲ tarix + ♡ sevimlilar (dumaloq
//     shisha tugmalar)
//   • Kategoriya chip qatori — "Barchasi" + yuklangan videolardagi janrlar
//     (yo'nalish). Tanlangani ko'k + X (bosib bekor qilinadi).
//   • Vertikal feed — full-width thumbnail + play + kanal/janr • ko'rishlar
//
// Logika: videolar backend `/api/content/videos` dan (yosh bo'yicha filtr).
// Kartani bosib turish (long-press) → sevimlilarga qo'shadi. Video ochilganda
// tarixga yoziladi (/video-player route). Ikkalasi SharedPreferences'da.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/video_engagement_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (dashboard bilan bir xil) ════════════
const _bg = Color(0xFF00060A); // sahifa foni
const _blue = Color(0xFF216BFF); // brend / faol chip
const _glass = Color(0x14FFFFFF); // shisha fon — oq ~8%
const _glassBorder = Color(0x24FFFFFF); // shisha chegara — oq ~14%
const _dim = Color(0x99FFFFFF); // oq 60%
const _muted = Color(0xFFA6A8A9); // xira kulrang (janr / ko'rishlar)
const _videoBg = Color(0xFF0E141C); // thumbnail neytral fon
const _sheetBg = Color(0xFF0B1119); // bottom sheet foni
const _fav = Color(0xFFFF4D67); // sevimli belgisi (qizil-pushti)

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.2,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

String _fmtViews(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return '$v';
}

/// Video uchun ko'rsatiladigan janr/yo'nalish yorlig'i (bo'sh bo'lsa fallback).
String _genre(VideoModel v) {
  for (final s in [v.yonalish, v.category, v.soha]) {
    final t = s.trim();
    if (t.isNotEmpty) return t;
  }
  return 'Video';
}

enum _SheetKind { history, favorites }

/// Bola videolar feed ekrani — "Videolar".
class VideosFeedScreen extends ConsumerWidget {
  /// `VideosFeedScreen` konstruktor.
  const VideosFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVideos = ref.watch(backendVideosProvider);
    final feed = ref.watch(videoFeedProvider);
    final categories = ref.watch(videoCategoriesProvider);
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
      // effectiveVideoCategoryProvider tufayli bu yerga faqat umuman video
      // bo'lmagan holatda kelamiz (tanlangan kategoriya doim video'li).
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + bottomInset),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
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
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: const ChildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _VideosHeader(),
            ),
            const SizedBox(height: 14),
            if (categories.isNotEmpty) ...[
              _CategoryChips(categories: categories),
              const SizedBox(height: 14),
            ],
            Expanded(
              // Pastga torting → yangilash (admin yangi video qo'shsa darhol).
              child: RefreshIndicator(
                color: _blue,
                backgroundColor: _videoBg,
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

// ════════════ Header: "Videolar" + tarix + sevimlilar ════════════

class _VideosHeader extends StatelessWidget {
  const _VideosHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Videolar',
            style: _unb(24, w: FontWeight.w600, ls: -0.72),
          ),
        ),
        _CircleIconButton(
          icon: Icons.history_rounded,
          onTap: () => _openSheet(context, _SheetKind.history),
        ),
        const SizedBox(width: 12),
        _CircleIconButton(
          icon: Icons.favorite_border_rounded,
          onTap: () => _openSheet(context, _SheetKind.favorites),
        ),
      ],
    );
  }
}

void _openSheet(BuildContext context, _SheetKind kind) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _VideoListSheet(
      kind: kind,
      onOpen: (video) {
        Navigator.of(sheetCtx).pop();
        context.push('/video-player', extra: video);
      },
    ),
  );
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
        decoration: const BoxDecoration(color: _glass, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

// ════════════ Kategoriya chiplari ════════════

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
              label: 'Barchasi',
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _blue : _glass,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: _glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: _pop(
                14,
                w: active ? FontWeight.w600 : FontWeight.w500,
                c: active ? Colors.white : _dim,
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
        ),
      ),
    );
  }
}

// ════════════ Feed kartasi (full-width) ════════════

class _FeedVideoCard extends ConsumerWidget {
  const _FeedVideoCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteVideoIdsProvider).contains(video.id);
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      // Bosib turish → sevimlilarga qo'shadi/olib tashlaydi.
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
              backgroundColor: _videoBg,
              duration: const Duration(milliseconds: 1400),
              content: Text(
                added
                    ? 'Sevimlilarga qo\'shildi'
                    : 'Sevimlilardan olib tashlandi',
                style: _pop(13, w: FontWeight.w500),
              ),
            ),
          );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(video: video, isFav: isFav),
          const SizedBox(height: 12),
          _Meta(video: video),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.video, required this.isFav});

  final VideoModel video;
  final bool isFav;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _videoBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, __) => ColoredBox(color: video.thumbnailColor),
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: video.thumbnailColor),
              )
            else
              ColoredBox(color: video.thumbnailColor),
            // Yumshoq pastki qorayish — play/badge o'qilishi uchun.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x4D000000)],
                ),
              ),
            ),
            const Center(child: _PlayBadge()),
            if (video.hasDuration)
              Positioned(
                right: 8,
                bottom: 8,
                child: _DurationPill(text: video.duration),
              ),
            if (isFav) const Positioned(top: 10, right: 10, child: _FavBadge()),
          ],
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: 30,
        color: Colors.white,
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: _pop(11, w: FontWeight.w600)),
    );
  }
}

class _FavBadge extends StatelessWidget {
  const _FavBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.favorite, size: 15, color: _fav),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(title: video.title, color: video.thumbnailColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _pop(15.5, w: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _genre(video),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(13, c: _muted),
                    ),
                  ),
                  Text('  •  ', style: _pop(13, c: _muted)),
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    size: 14,
                    color: _muted,
                  ),
                  const SizedBox(width: 4),
                  Text(_fmtViews(video.views), style: _pop(13, c: _muted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title[0].toUpperCase() : '?',
        style: _pop(17, w: FontWeight.w700),
      ),
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
              color: _glass,
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
                color: _glass,
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
                      color: _glass,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: 140,
                    decoration: BoxDecoration(
                      color: _glass,
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

/// Bo'sh holat — FARO maskot + qat'iy ranglar (screen doim dark, shuning
/// uchun theme-adaptive EmptyStateMascot o'rniga o'z ranglarimiz — light
/// theme'da ham matn o'qiladi).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const FaroMascot(variant: FaroVariant.faceSad, size: 130),
          const SizedBox(height: 20),
          Text(
            'Videolar hozircha yo\'q',
            textAlign: TextAlign.center,
            style: _unb(18, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Tez orada yangi videolar qo\'shiladi',
            textAlign: TextAlign.center,
            style: _pop(14, c: _dim),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onRefresh,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Yangilash', style: _pop(14, w: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Tarix / Sevimlilar bottom sheet ════════════

class _VideoListSheet extends ConsumerWidget {
  const _VideoListSheet({required this.kind, required this.onOpen});

  final _SheetKind kind;
  final void Function(VideoModel) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = kind == _SheetKind.history
        ? ref.watch(watchHistoryVideosProvider)
        : ref.watch(favoriteVideosProvider);
    final title = kind == _SheetKind.history
        ? 'Ko\'rish tarixi'
        : 'Sevimli videolar';
    final emptyText = kind == _SheetKind.history
        ? 'Hali video ko\'rmadingiz'
        : 'Hali sevimli video yo\'q';
    final emptyHint = kind == _SheetKind.history
        ? 'Ko\'rgan videolaringiz shu yerda chiqadi'
        : 'Videoni bosib turib sevimlilarga qo\'shing';
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: _glassBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: _unb(18, w: FontWeight.w600, ls: -0.4),
                  ),
                ),
                if (videos.isNotEmpty)
                  Text('${videos.length}', style: _pop(13, c: _muted)),
              ],
            ),
          ),
          Flexible(
            child: videos.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 40 + bottomInset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          kind == _SheetKind.history
                              ? Icons.history_rounded
                              : Icons.favorite_border_rounded,
                          size: 44,
                          color: _muted,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: _pop(15, w: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          emptyHint,
                          textAlign: TextAlign.center,
                          style: _pop(13, c: _dim),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottomInset),
                    itemCount: videos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _CompactRow(
                      video: videos[i],
                      onTap: () => onOpen(videos[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.video, required this.onTap});

  final VideoModel video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 116,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: video.thumbnailColor),
                      errorWidget: (_, __, ___) =>
                          ColoredBox(color: video.thumbnailColor),
                    )
                  else
                    ColoredBox(color: video.thumbnailColor),
                  Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(14, w: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _genre(video),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(12, c: _muted),
                      ),
                    ),
                    Text('  •  ', style: _pop(12, c: _muted)),
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 13,
                      color: _muted,
                    ),
                    const SizedBox(width: 3),
                    Text(_fmtViews(video.views), style: _pop(12, c: _muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
