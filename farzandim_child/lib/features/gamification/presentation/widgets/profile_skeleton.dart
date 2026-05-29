// ─────────────────────────────────────────────────────────────────────
// ProfileSkeleton — Profile loading state (CircularProgress o'rniga)
// ─────────────────────────────────────────────────────────────────────
//
// Modern UX: foydalanuvchi nima yuklanayotganini "ko'radi" (kelajak
// shakli) — bo'sh spinner emas. Shimmer effect bilan animatsiya.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceVariant,
      period: const Duration(milliseconds: 1500),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50), // top header joyi
            // Avatar + ism + status badge
            Row(
              children: [
                _circle(64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 180, height: 24),
                      const SizedBox(height: 8),
                      _box(width: 120, height: 20, radius: 999),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Level progress card
            _box(width: double.infinity, height: 140),
            const SizedBox(height: 16),
            // DON + Streak yon
            Row(
              children: [
                Expanded(child: _box(width: double.infinity, height: 84)),
                const SizedBox(width: 12),
                Expanded(child: _box(width: double.infinity, height: 84)),
              ],
            ),
            const SizedBox(height: 24),
            _box(width: 160, height: 22), // sarlavha
            const SizedBox(height: 12),
            // Achievement grid (2 qator x 3 ustun)
            for (var i = 0; i < 2; i++) ...[
              Row(
                children: [
                  Expanded(child: _box(width: double.infinity, height: 110)),
                  const SizedBox(width: 12),
                  Expanded(child: _box(width: double.infinity, height: 110)),
                  const SizedBox(width: 12),
                  Expanded(child: _box(width: double.infinity, height: 110)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _box({
    required double width,
    required double height,
    double radius = 12,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
