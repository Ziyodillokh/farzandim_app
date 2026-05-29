import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';

/// Bildirishnomalar ekranidagi bitta kartochka.
///
/// **Vizual farq o'qilgan/o'qilmagan:**
/// - O'qilmagan: `surfaceVariant` fon, lime green chegara, sarlavha bold,
///   o'ngda lime green dot
/// - O'qilgan: `surface` fon, chegara yo'q, sarlavha medium weight
class NotificationCard extends StatelessWidget {
  /// `NotificationCard` konstruktor.
  const NotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  /// Ko'rsatiladigan xabar.
  final AppNotification notification;

  /// Karta bossa — list bilan provider'ga `markAsRead` chaqiriladi va
  /// type bo'yicha tegishli ekranga navigatsiya qilinadi.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: isRead ? AppColors.surface : AppColors.surfaceVariant,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            border: isRead
                ? null
                : Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      notification.type.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  notification.type.icon,
                  color: notification.type.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyS.copyWith(
                              fontSize: 15,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatRelativeTime(notification.timestamp),
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
        ),
      ),
    );
  }
}
