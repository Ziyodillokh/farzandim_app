import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'common.dart';

class _Bone extends StatelessWidget {
  const _Bone({required this.height, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    );
  }
}

class UsersTableSkeleton extends StatelessWidget {
  const UsersTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const _Bone(height: 16, width: 120),
                  const Spacer(),
                  const _Bone(height: 16, width: 80),
                  const SizedBox(width: AppSpacing.md),
                  const _Bone(height: 16, width: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      children: [
        const _Bone(height: 28, width: 200),
        const SizedBox(height: AppSpacing.xs),
        const _Bone(height: 16, width: 280),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(
            6,
            (_) => SizedBox(
              width: 252,
              child: AppCard(
                child: SizedBox(
                  height: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Bone(height: 14, width: 100),
                      const Spacer(),
                      const _Bone(height: 28, width: 72),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppCard(
                child: SizedBox(
                  height: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Bone(height: 16, width: 120),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppRadius.control),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppCard(
                child: SizedBox(
                  height: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Bone(height: 16, width: 120),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppRadius.control),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ContentListSkeleton extends StatelessWidget {
  const ContentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const _Bone(height: 78, width: 128),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Bone(height: 16, width: 220),
                      const SizedBox(height: AppSpacing.xs),
                      const _Bone(height: 12, width: 160),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      children: [
        const _Bone(height: 28, width: 180),
        const SizedBox(height: AppSpacing.xs),
        const _Bone(height: 14, width: 260),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(
            3,
            (_) => SizedBox(
              width: 200,
              child: AppCard(
                child: SizedBox(
                  height: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Bone(height: 12, width: 80),
                      const Spacer(),
                      const _Bone(height: 22, width: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: const SizedBox(
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE8ECF0),
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationHistorySkeleton extends StatelessWidget {
  const NotificationHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Bone(height: 16, width: 200),
                  const SizedBox(height: AppSpacing.xxs),
                  const _Bone(height: 12, width: 140),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
