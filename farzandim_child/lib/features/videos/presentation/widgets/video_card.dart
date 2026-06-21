// ─────────────────────────────────────────────────────────────────────
// VideoCard — section'lardagi kichik card (160x180)
// ─────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({required this.video, super.key});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail — Image.network bilan errorBuilder/loadingBuilder
            // (avval DecorationImage'da xato handling yo'q edi).
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 120,
                width: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.thumbnailUrl.isNotEmpty)
                      // Disk-cache (cached_network_image): thumbnail bir marta
                      // yuklangach keyingi safar (offline ham) darhol chiqadi.
                      CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 180),
                        placeholder: (_, __) =>
                            Container(color: video.thumbnailColor),
                        errorWidget: (_, __, ___) =>
                            Container(color: video.thumbnailColor),
                      )
                    else
                      Container(color: video.thumbnailColor),
                    // Dark gradient overlay — chap pastdan o'ngga, duration
                    // pill o'qish uchun (har qanday rasm ustida ishlaydi).
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            // ignore: deprecated_member_use
                            Colors.black.withOpacity(0.4),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          AppIcons.play,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    // Duration faqat ma'lum bo'lsa (YouTube linkda 0 bo'ladi).
                    if (video.hasDuration)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Adaptive ranglar — dark mode'da AppColors.textPrimary qora
            // bo'lgani uchun matn ko'rinmasdi. context.adaptive teme
            // bo'yicha avtomatik oq/qora tanlaydi.
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.adaptive.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              video.category,
              style: TextStyle(
                color: context.adaptive.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
