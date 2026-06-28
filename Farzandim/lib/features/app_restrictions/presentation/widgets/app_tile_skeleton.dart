import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Skeleton loader (animated shimmer) — ilovalar yuklanayotganda
/// Premium tuyg'usi uchun. 1.2 sek davriy alpha 0.3 ↔ 0.6.
///
/// Tile layout'iga mos: 48 ikon, sarlavha qatori, progress bar, vaqt.
class AppTileSkeleton extends StatefulWidget {
  /// `AppTileSkeleton` konstruktor.
  const AppTileSkeleton({super.key});

  @override
  State<AppTileSkeleton> createState() => _AppTileSkeletonState();
}

class _AppTileSkeletonState extends State<AppTileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final color = AppColors.textSecondary.withValues(
          alpha: _animation.value * 0.3,
        );
        final radius = BorderRadius.circular(4);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm + 4,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: radius,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: radius,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
