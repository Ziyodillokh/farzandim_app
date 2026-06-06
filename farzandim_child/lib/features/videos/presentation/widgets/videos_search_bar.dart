// ─────────────────────────────────────────────────────────────────────
// VideosSearchBar — search field + filter ikon (badge bilan)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_filter_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideosSearchBar extends ConsumerStatefulWidget {
  const VideosSearchBar({super.key});

  @override
  ConsumerState<VideosSearchBar> createState() =>
      _VideosSearchBarState();
}

class _VideosSearchBarState extends ConsumerState<VideosSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFilter(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const VideoFilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(videoFilterProvider);
    final filterCount = filter.count;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: context.adaptive.bgCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: context.adaptive.border, width: 0.5),
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(color: context.adaptive.textPrimary),
                decoration: InputDecoration(
                  hintText: 'videos.feed.searchHint'.tr(),
                  hintStyle: TextStyle(
                      color: context.adaptive.textTertiary),
                  prefixIcon: Icon(Icons.search,
                      color: context.adaptive.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  ref.read(videoSearchQueryProvider.notifier).state =
                      value;
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openFilter(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: filterCount > 0
                    ? AppColors.primary
                    : context.adaptive.bgCard,
                borderRadius: BorderRadius.circular(22),
                border: filterCount > 0
                    ? null
                    : Border.all(
                        color: context.adaptive.border, width: 0.5),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.tune,
                      color: filterCount > 0
                          ? Colors.black
                          : context.adaptive.textPrimary,
                    ),
                  ),
                  if (filterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$filterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
