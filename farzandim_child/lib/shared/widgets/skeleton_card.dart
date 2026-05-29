// ─────────────────────────────────────────────────────────────────────
// SkeletonCard — shimmer loading state (zamonaviy app standarti)
// ─────────────────────────────────────────────────────────────────────
//
// CircularProgressIndicator o'rniga keladi: foydalanuvchi nima yuklanayotganini
// oldindan ko'radi (kartochka shakli) va kutish vaqti kamroq sezgi
// uyg'otadi.
//
// Foydalanish:
//   SkeletonList(itemCount: 5, itemHeight: 88)
//   SkeletonCard(height: 120)
//   SkeletonAvatar(size: 48)

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Asosiy skeleton box — istalgan shape uchun.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceVariant,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: shape,
          borderRadius:
              shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Avatar shape skeleton (circle).
class SkeletonAvatar extends StatelessWidget {
  const SkeletonAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }
}

/// Card-shape skeleton (rectangle radius 16) — Dashboard kartochkalari uchun.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 100,
    this.width = double.infinity,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(16),
    );
  }
}

/// List skeleton — ListView orniga (kartochka stack'i).
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 120),
    this.spacing = 12,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, __) => SkeletonCard(height: itemHeight),
    );
  }
}

/// Notification/social post style skeleton — avatar + 2 ta matn qator.
class SkeletonRowCard extends StatelessWidget {
  const SkeletonRowCard({super.key, this.height = 88});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceVariant,
      period: const Duration(milliseconds: 1500),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
