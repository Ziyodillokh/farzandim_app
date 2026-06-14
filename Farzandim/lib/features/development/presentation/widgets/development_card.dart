// ─────────────────────────────────────────────────────────────────────
// DevelopmentCard (Parent) — farzand rivojlanish ko'rsatkichi (#63)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona farzand rivojini kuzatadi — ijobiy, motivatsion (nazorat emas).
// Halqali indeks (0..100) + trend + asosiy ko'rsatkichlar.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/development/data/development_summary.dart';
import 'package:flutter/material.dart';

class DevelopmentCard extends StatelessWidget {
  const DevelopmentCard({required this.summary, super.key});

  final DevelopmentSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rivojlanish',
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bu haftalik faollik',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _TrendChip(trend: s.trend),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              _ScoreRing(score: s.score),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.quiz_rounded,
                          color: AppColors.info,
                          label: 'Test',
                          value: '${s.testsCompleted}',
                        ),
                        _Metric(
                          icon: Icons.menu_book_rounded,
                          color: AppColors.success,
                          label: 'Kitob',
                          value: '${s.booksRead}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.warning,
                          label: 'Streak',
                          value: '${s.streakDays} kun',
                        ),
                        _Metric(
                          icon: Icons.directions_walk_rounded,
                          color: AppColors.primary,
                          label: 'Qadam',
                          value: _compact(s.steps),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!s.hasActivity) ...[
            const SizedBox(height: 12),
            Text(
              "Bu hafta hali faollik yo'q. Farzandingizni test va kitobga "
              'undang! 🌱',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return '$n';
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});
  final int score;

  Color get _color {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 9,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: AppTextStyles.headlineL.copyWith(
                  fontSize: 24,
                  height: 1,
                ),
              ),
              Text(
                '/ 100',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});
  final int trend;

  @override
  Widget build(BuildContext context) {
    final up = trend >= 0;
    final color = up ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${trend.abs()}%',
            style: AppTextStyles.label.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
