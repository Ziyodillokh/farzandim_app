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
                    // Premium YouTube-style: to'liq rangli kvadrat (rounded),
                    // oq ikona, nozik shadow + glow. Avval rang withOpacity'li
                    // circle edi — past kontrast tufayli "xira" tuyulgan.
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: leadingIconColor ?? AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (leadingIconColor ?? AppColors.primary)
                                // ignore: deprecated_member_use
                                .withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        leadingIcon,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.adaptive.textPrimary,
                      letterSpacing: -0.2,
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
