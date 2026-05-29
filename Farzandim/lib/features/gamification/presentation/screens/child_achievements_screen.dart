// ─────────────────────────────────────────────────────────────────────
// ChildAchievementsScreen — "Bola yutuqlari" (Sprint 4.4.6)
// ─────────────────────────────────────────────────────────────────────
//
// Parent App'da bola gamification profili: XP/Level/DON/Streak +
// achievements list. Backend `/api/children/:childId/profile`.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/gamification/data/repositories/backend_gamification_repository.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola yutuqlari ekrani — XP/Level/DON/Streak overview.
class ChildAchievementsScreen extends ConsumerWidget {
  /// `ChildAchievementsScreen` konstruktor.
  const ChildAchievementsScreen({required this.childId, super.key});

  /// Qaysi bola yutuqlari ko'rsatiladi.
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final childName = child?.name ?? 'Bola';
    final profileAsync = ref.watch(childProfileProvider(childId));
    final eventsAsync = ref.watch(childXpEventsProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(childName: childName),
              Expanded(
                child: profileAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        'Yuklanmadi: $e',
                        style: AppTextStyles.bodyM,
                      ),
                    ),
                  ),
                  data: (profile) {
                    if (profile == null) {
                      return const _EmptyState();
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LevelCard(profile: profile),
                          const SizedBox(height: AppDimensions.md),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStatCard(
                                  icon: Icons.star_rounded,
                                  color: AppColors.warning,
                                  label: 'XP',
                                  value: '${profile.xp}',
                                ),
                              ),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: _MiniStatCard(
                                  icon: Icons.diamond_rounded,
                                  color: const Color(0xFFFFD700),
                                  label: 'DON',
                                  value: '${profile.donBalance}',
                                ),
                              ),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: _MiniStatCard(
                                  icon:
                                      Icons.local_fire_department_rounded,
                                  color: AppColors.error,
                                  label: 'Streak',
                                  value: '${profile.streakDays} kun',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          if (profile.achievements.isNotEmpty) ...[
                            Text(
                              'Yutuqlar',
                              style: AppTextStyles.headlineL,
                            ),
                            const SizedBox(height: AppDimensions.md),
                            _AchievementsGrid(
                              achievements: profile.achievements,
                            ),
                            const SizedBox(height: AppDimensions.lg),
                          ],
                          Text(
                            'So\'nggi faolligi',
                            style: AppTextStyles.headlineL,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          eventsAsync.when(
                            loading: () => const SizedBox(
                              height: 100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            error: (e, _) =>
                                Text('Tarix yuklanmadi: $e'),
                            data: (events) => events.isEmpty
                                ? Text(
                                    'Hali XP faolligi yo\'q',
                                    style: AppTextStyles.bodyS.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (final e in events)
                                        _XpEventTile(event: e),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: AppDimensions.xl),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.childName});
  final String childName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$childName yutuqlari',
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.profile});
  final ChildProfile profile;

  @override
  Widget build(BuildContext context) {
    // Level progress — XP'dan keyingi level uchun
    // (level = floor(sqrt(xp) / 5) + 1 formula).
    final nextLevel = profile.level + 1;
    final nextLevelXp = ((nextLevel - 1) * 5) * ((nextLevel - 1) * 5);
    final prevLevelXp = ((profile.level - 1) * 5) * ((profile.level - 1) * 5);
    final progress = nextLevelXp > prevLevelXp
        ? ((profile.xp - prevLevelXp) / (nextLevelXp - prevLevelXp))
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD0FF6E), Color(0xFFA3CE4F)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.black, size: 32),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${profile.level}',
                      style: AppTextStyles.headlineXL.copyWith(
                        color: Colors.black,
                        fontSize: 28,
                      ),
                    ),
                    Text(
                      profile.status,
                      style: AppTextStyles.bodyM.copyWith(
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.xp} / $nextLevelXp XP',
            style: AppTextStyles.bodyS.copyWith(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.headlineL.copyWith(fontSize: 18)),
          Text(
            label,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.achievements});
  final List<Map<String, dynamic>> achievements;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.md,
      runSpacing: AppDimensions.md,
      children: [
        for (final a in achievements)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary),
            ),
            child: Text(
              (a['name'] as String?) ?? '🏆',
              style: AppTextStyles.bodyS,
            ),
          ),
      ],
    );
  }
}

class _XpEventTile extends StatelessWidget {
  const _XpEventTile({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final type = (event['type'] as String?) ?? 'OTHER';
    final xp = (event['xpDelta'] as num?)?.toInt() ?? 0;
    final don = (event['donDelta'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline_rounded,
              color: AppColors.success, size: 24),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(type, style: AppTextStyles.bodyM),
          ),
          if (xp > 0)
            Text(
              '+$xp XP',
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (don > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+$don DON',
              style: AppTextStyles.bodyS.copyWith(
                color: const Color(0xFFFFD700),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_outlined,
                color: AppColors.textSecondary, size: 64),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Bola hali faollik ko\'rsatmagan',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
