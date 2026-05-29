// ─────────────────────────────────────────────────────────────────────
// VideoTabs — Following / Siz uchun
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoTabs extends ConsumerWidget {
  const VideoTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(videoActiveTabProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Tab(
            label: 'videos.feed.tabFollowing'.tr(),
            isActive: activeTab == 0,
            onTap: () =>
                ref.read(videoActiveTabProvider.notifier).state = 0,
          ),
          const SizedBox(width: 24),
          _Tab(
            label: 'videos.feed.tabForYou'.tr(),
            isActive: activeTab == 1,
            onTap: () =>
                ref.read(videoActiveTabProvider.notifier).state = 1,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: 32,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
