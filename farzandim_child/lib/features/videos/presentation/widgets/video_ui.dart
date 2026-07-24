// ─────────────────────────────────────────────────────────────────────
// video_ui — Videolar bo'limi uchun umumiy Parvoz tokenlari + VideoFeedCard
// ─────────────────────────────────────────────────────────────────────
//
// Feed (VideosFeedScreen), Ko'rish tarixi va Yoqtirilgan videolar sahifalari
// bir xil full-width kartani ishlatadi — shu yerda markazlashgan.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (dashboard/feed bilan bir xil) ════════════
const vBg = Color(0xFF00060A); // sahifa foni
const vBlue = Color(0xFF216BFF); // brend / faol
const vGlass = Color(0x14FFFFFF); // shisha fon — oq ~8%
const vGlassBorder = Color(0x24FFFFFF); // shisha chegara — oq ~14%
const vDim = Color(0x99FFFFFF); // oq 60%
const vMuted = Color(0xFFA6A8A9); // xira kulrang
const vVideoBg = Color(0xFF0E141C); // thumbnail neytral fon
const vFav = Color(0xFFFF4D67); // sevimli belgisi (qizil-pushti)

TextStyle vUnb(
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

TextStyle vPop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

String vFmtViews(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return '$v';
}

/// Video uchun janr yorlig'i — `category` (backend slug'i humanlashtirilgan;
/// `yonalish` mapper'da "Ta'lim" hardcode, shuning uchun ishlatilmaydi).
String vGenre(VideoModel v) {
  final c = v.category.trim();
  return c.isNotEmpty ? c : 'videos.genreFallback'.tr();
}

/// Full-width video kartasi — 16:9 thumbnail + play + kanal/janr • ko'rishlar.
/// Feed, tarix va yoqtirilganlar sahifalarida bir xil ishlatiladi.
class VideoFeedCard extends StatelessWidget {
  const VideoFeedCard({
    required this.video,
    required this.onTap,
    this.isFavorite = false,
    this.onLongPress,
    this.trailing,
    super.key,
  });

  final VideoModel video;

  /// Thumbnail burchagida ♡ badge ko'rsatiladimi.
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Meta qatori oxiridagi widget (masalan yoqtirilganlar sahifasidagi ♥ toggle).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(video: video, isFavorite: isFavorite),
          const SizedBox(height: 12),
          _Meta(video: video, trailing: trailing),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.video, required this.isFavorite});

  final VideoModel video;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: vVideoBg,
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
            if (isFavorite)
              const Positioned(top: 10, right: 10, child: _FavBadge()),
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
      child: Text(text, style: vPop(11, w: FontWeight.w600)),
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
      child: const Icon(Icons.favorite, size: 15, color: vFav),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.video, this.trailing});

  final VideoModel video;
  final Widget? trailing;

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
                style: vPop(15.5, w: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      vGenre(video),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: vPop(13, c: vMuted),
                    ),
                  ),
                  Text('  •  ', style: vPop(13, c: vMuted)),
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    size: 14,
                    color: vMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(vFmtViews(video.views), style: vPop(13, c: vMuted)),
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
        style: vPop(17, w: FontWeight.w700),
      ),
    );
  }
}
