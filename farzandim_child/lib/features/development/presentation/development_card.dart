// ─────────────────────────────────────────────────────────────────────
// DevelopmentCard — yaxlit rivojlanish indeksi (#63)
// ─────────────────────────────────────────────────────────────────────
//
// Halqali indeks (0..100) + trend strelkasi + asosiy ko'rsatkichlar
// (test/kitob/streak/qadam). Ijobiy, motivatsion ohang.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/development/data/development_summary.dart';
import 'package:flutter/material.dart';

class DevelopmentCard extends StatelessWidget {
  const DevelopmentCard({required this.summary, super.key});

  final DevelopmentSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'development.title'.tr(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TrendChip(trend: s.trend),
            ],
          ),
          const SizedBox(height: 16),
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
                          color: AppColors.catBlue,
                          label: 'development.tests'.tr(),
                          value: '${s.testsCompleted}',
                        ),
                        _Metric(
                          icon: Icons.menu_book_rounded,
                          color: AppColors.catMint,
                          label: 'development.books'.tr(),
                          value: '${s.booksRead}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.catOrangeLight,
                          label: 'development.streak'.tr(),
                          value: 'gamification.streakDays'.tr(
                            namedArgs: {'days': '${s.streakDays}'},
                          ),
                        ),
                        _Metric(
                          icon: Icons.directions_walk_rounded,
                          color: AppColors.catLavenderDark,
                          label: 'development.steps'.tr(),
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
            const SizedBox(height: 14),
            Text(
              'Bu hafta sayohatni boshla — test yech, kitob o\'qi, '
              'harakat qil! 🚀',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
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
    if (score >= 70) return AppColors.catMint;
    if (score >= 40) return AppColors.catOrangeLight;
    return AppColors.catBlue;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '/ 100',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
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
    final color = up ? AppColors.catMint : AppColors.error;
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
            style: TextStyle(
              color: color,
              fontSize: 12,
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
