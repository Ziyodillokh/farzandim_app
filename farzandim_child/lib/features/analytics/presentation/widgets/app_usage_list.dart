// ─────────────────────────────────────────────────────────────────────
// AppUsageList — Sprint 4.4.32 real Backend usage + limit + icon
// ─────────────────────────────────────────────────────────────────────
//
// `dailyUsageProvider` + `childAppLimitsProvider` merge:
//   - Top N ilova (totalTimeMs DESC)
//   - Har ilova uchun: icon (base64 yoki Material fallback), nom,
//     foydalanish vaqti, Parent limit (agar bor) + qolgan vaqt yoki
//     limit oshganligi belgisi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:convert';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/analytics/data/models/app_usage_entry.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppUsageList extends ConsumerWidget {
  const AppUsageList({this.limit, super.key});

  /// Top-N (null → barchasi).
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(dailyUsageProvider);
    final limitsAsync = ref.watch(childAppLimitsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: usageAsync.when(
        loading: () => const _LoadingBox(),
        error: (_, __) => const _EmptyBox(text: "Ma'lumot yuklanmadi"),
        data: (day) {
          if (day.apps.isEmpty) {
            return const _EmptyBox(text: "Bugun ilova ishlatilmagan");
          }
          final visible = limit != null && limit! < day.apps.length
              ? day.apps.take(limit!).toList()
              : day.apps;
          final limits = limitsAsync.valueOrNull ?? const <AppLimit>[];
          final limitMap = <String, AppLimit>{
            for (final l in limits) l.packageName: l,
          };
          return Column(
            children: List.generate(visible.length, (i) {
              final app = visible[i];
              final lim = limitMap[app.packageName];
              return Column(
                children: [
                  _UsageRow(app: app, limit: lim),
                  if (i < visible.length - 1)
                    const Divider(
                      color: AppColors.border,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.app, required this.limit});

  final AppUsageEntry app;
  final AppLimit? limit;

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();
    final trailing = _buildTrailing();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _AppIcon(app: app),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName.isEmpty ? app.packageName : app.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                subtitle,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    final lim = limit;
    if (lim == null) {
      return Text(
        app.formattedTime,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      );
    }

    if (lim.isFullBlock) {
      return const Row(
        children: [
          Icon(AppIcons.block, size: 13, color: AppColors.error),
          SizedBox(width: 4),
          Text(
            'Bloklangan',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final usedMs = app.totalTimeMs;
    final limitMs = lim.dailyLimitMs;
    final percent = limitMs == 0 ? 0.0 : (usedMs / limitMs).clamp(0.0, 1.0);
    final remainingMs = limitMs - usedMs;
    final overLimit = remainingMs <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${app.formattedTime} / ${_formatMs(limitMs)}',
              style: TextStyle(
                fontSize: 13,
                color: overLimit
                    ? AppColors.error
                    : AppColors.textSecondary,
                fontWeight:
                    overLimit ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (overLimit) ...[
              const SizedBox(width: 6),
              const Icon(
                AppIcons.warning,
                size: 13,
                color: AppColors.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.toDouble(),
            minHeight: 4,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              overLimit ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildTrailing() {
    final lim = limit;
    if (lim == null || lim.isFullBlock) return null;
    final remainingMs = lim.dailyLimitMs - app.totalTimeMs;
    if (remainingMs <= 0) {
      return const Text(
        'Tugadi',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.error,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Qoldi',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          _formatMs(remainingMs),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static String _formatMs(int ms) {
    final m = ms ~/ 60000;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h == 0) return '${mm}m';
    if (mm == 0) return '${h}s';
    return '${h}s ${mm}m';
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  final AppUsageEntry app;

  @override
  Widget build(BuildContext context) {
    final size = 40.0;
    final radius = BorderRadius.circular(10);

    // 1. iconUrl (MinIO signed URL)
    if (app.iconUrl != null && app.iconUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          app.iconUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Fallback(app: app, size: size),
        ),
      );
    }

    // 2. iconBase64
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64!);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {
        // base64 noto'g'ri → fallback
      }
    }

    // 3. Fallback
    return _Fallback(app: app, size: size);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.app, required this.size});
  final AppUsageEntry app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _colorForPackage(app.packageName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        _initialsForName(app.appName.isEmpty ? app.packageName : app.appName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initialsForName(String name) {
    final clean = name.split('.').last;
    if (clean.isEmpty) return '?';
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Paket nomidan deterministik rang (hash → palette).
  static Color _colorForPackage(String pkg) {
    const palette = [
      AppColors.catIndigo, // indigo
      AppColors.catPurple, // violet
      AppColors.catPink, // pink
      AppColors.danger, // red
      AppColors.warning, // amber
      AppColors.catEmerald, // emerald
      AppColors.catBlue, // blue
      AppColors.catTeal, // teal
    ];
    final hash = pkg.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
