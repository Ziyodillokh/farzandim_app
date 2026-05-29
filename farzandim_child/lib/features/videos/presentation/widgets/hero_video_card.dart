// ─────────────────────────────────────────────────────────────────────
// HeroVideoCard — feed yuqorisidagi katta vertikal card (PDF p5)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HeroVideoCard extends StatelessWidget {
  const HeroVideoCard({required this.video, super.key});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/video-player', extra: video),
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            color: video.thumbnailColor,
            borderRadius: BorderRadius.circular(20),
            image: video.thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(video.thumbnailUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      // Rasm ustida o'qiladigan bo'lishi uchun yuqori qism qoramtir
                      // ignore: deprecated_member_use
                      Colors.black.withOpacity(video.thumbnailUrl.isNotEmpty ? 0.15 : 0),
                      // ignore: deprecated_member_use
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.play,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    video.duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
