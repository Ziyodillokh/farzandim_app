// ─────────────────────────────────────────────────────────────────────
// VideoSection — sarlavha + horizontal video card list
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_card.dart';
import 'package:flutter/material.dart';

class VideoSection extends StatelessWidget {
  const VideoSection({
    required this.title,
    required this.videos,
    this.onViewAll,
    this.leadingIcon,
    this.leadingIconColor,
    super.key,
  });

  final String title;
  final List<VideoModel> videos;
  final VoidCallback? onViewAll;

  /// Sarlavha oldida rangli yumaloq fonda ko'rinadigan Material ikon.
  final IconData? leadingIcon;
  final Color? leadingIconColor;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (leadingIcon != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: (leadingIconColor ?? AppColors.primary)
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        leadingIcon,
                        size: 16,
                        color: leadingIconColor ?? AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.adaptive.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'videos.feed.viewAll'.tr(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          // 120 thumbnail + meta (title 2 lines + category) ≈ 184
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => VideoCard(video: videos[i]),
          ),
        ),
      ],
    );
  }
}
