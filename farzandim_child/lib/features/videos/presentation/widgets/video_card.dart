// ─────────────────────────────────────────────────────────────────────
// VideoCard — section'lardagi kichik card (160x180)
// ─────────────────────────────────────────────────────────────────────

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
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: video.thumbnailColor,
                borderRadius: BorderRadius.circular(12),
                image: video.thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(video.thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.play,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              video.category,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
