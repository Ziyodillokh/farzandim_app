import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_combined.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:flutter/material.dart';

/// PDF p13 dizayniga moslashtirilgan ilova tile'i, premium UX bilan:
/// - Native ikon (yoki paket nomidan fallback)
/// - Status emoji (🟢/🟡/🔴/⛔)
/// - Progress bar (limit'ga nisbatan, status rangi)
/// - Foydalanish / limit row (Apple Screen Time pattern)
///
/// Tap → limit bottom sheet. Long-press → quick actions menu.
class AppCombinedTile extends StatelessWidget {
  /// `AppCombinedTile` konstruktor.
  const AppCombinedTile({
    required this.app,
    super.key,
    this.onTap,
    this.onLongPress,
  });

  /// Ko'rsatiladigan combined ilova ma'lumoti.
  final AppCombined app;

  /// Tap callback — limit bottom sheet ochiladi.
  final VoidCallback? onTap;

  /// Long press callback — quick actions menu.
  final VoidCallback? onLongPress;

  /// Status uchun rang (progress bar, usage matni).
  Color _statusColor(UsageStatus status) {
    switch (status) {
      case UsageStatus.healthy:
        return AppColors.success;
      case UsageStatus.warning:
        return AppColors.warning;
      case UsageStatus.exceeded:
      case UsageStatus.blocked:
        return AppColors.error;
      case UsageStatus.noLimit:
        return AppColors.textSecondary;
    }
  }

  /// Status emoji — `noLimit` uchun bo'sh string.
  String _statusEmoji(UsageStatus status) {
    switch (status) {
      case UsageStatus.healthy:
        return '🟢';
      case UsageStatus.warning:
        return '🟡';
      case UsageStatus.exceeded:
        return '🔴';
      case UsageStatus.blocked:
        return '⛔';
      case UsageStatus.noLimit:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLimit = app.hasLimit;
    final isBlocked = app.isBlocked;
    final progress = app.progressRatio;
    final statusColor = _statusColor(app.status);
    final emoji = _statusEmoji(app.status);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm + 4,
        ),
        child: Row(
          children: [
            AppIconWidget(
              iconUrl: app.iconUrl,
              iconBase64: app.iconBase64,
              packageName: app.packageName,
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.appName.isEmpty
                              ? app.packageName
                              : app.appName,
                          style: AppTextStyles.bodyM.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (emoji.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (hasLimit && !isBlocked) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: AppColors.textSecondary
                            .withValues(alpha: 0.1),
                        color: statusColor,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _UsageRow(
                    app: app,
                    statusColor: statusColor,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile pastki qatori — uch holat:
/// - Bloklangan: qizil "block" ikon + "Bloklangan" matn
/// - Limit bor: `usage / limit` (status rangi + kulrang)
/// - Limit yo'q: faqat `usage` (kulrang)
class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.app, required this.statusColor});

  final AppCombined app;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    if (app.isBlocked) {
      return Row(
        children: [
          const Icon(
            Icons.block,
            color: AppColors.error,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'Bloklangan',
            style: AppTextStyles.label.copyWith(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (app.hasLimit) {
      return Row(
        children: [
          Text(
            app.usageFormatted,
            style: AppTextStyles.label.copyWith(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            ' / ${app.limitFormatted}',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Text(
      app.usageFormatted,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textSecondary,
        fontSize: 12,
      ),
    );
  }
}
