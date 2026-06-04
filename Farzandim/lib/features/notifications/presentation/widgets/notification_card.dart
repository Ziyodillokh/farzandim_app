import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';

/// Bildirishnomalar ekranidagi bitta kartochka (Figma 1:1).
///
/// **Ikki variant:**
/// - **Aksiyali** (`isActionable`, masalan pair so'rov): sarlavha + bola
///   ismi + meta + qizil o'qilmagan nuqta + "Tekshirish" / "Rad etish".
/// - **Info** (batareya, zona, jadval, ...): ikona + sarlavha + meta
///   (bola • vaqt), tugmasiz.
class NotificationCard extends StatelessWidget {
  /// `NotificationCard` konstruktor.
  const NotificationCard({
    required this.notification,
    required this.onTap,
    this.onReview,
    this.onReject,
    super.key,
  });

  /// Ko'rsatiladigan xabar.
  final AppNotification notification;

  /// Karta bossa — `markAsRead` + type bo'yicha navigatsiya.
  final VoidCallback onTap;

  /// "Tekshirish" tugmasi (faqat aksiyali xabarlar uchun).
  final VoidCallback? onReview;

  /// "Rad etish" tugmasi (faqat aksiyali xabarlar uchun).
  final VoidCallback? onReject;

  bool get _actionable =>
      notification.isActionable && onReview != null && onReject != null;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusL);
    final title = notification.title.trim().isNotEmpty
        ? notification.title
        : notification.message;

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(notification: notification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyM.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_actionable) ...[
                          if (notification.childName.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              notification.childName,
                              style: AppTextStyles.bodyS.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            _meta(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            _meta(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    const _UnreadDot(),
                  ],
                ],
              ),
              if (_actionable) ...[
                const SizedBox(height: AppDimensions.md),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: 'notifications.review'.tr(),
                        onTap: onReview!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        label: 'notifications.reject'.tr(),
                        onTap: onReject!,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Meta qatori — "Hozir • Sevinch" yoki info'da "Sevinch • Kecha".
  String _meta() {
    final time = _capitalize(formatRelativeTime(notification.timestamp));
    if (_actionable) {
      return time;
    }
    final parts = <String>[
      if (notification.childName.trim().isNotEmpty) notification.childName,
      time,
    ];
    return parts.join(' • ');
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ════════════════════════ AVATAR ════════════════════════

class _Avatar extends StatelessWidget {
  const _Avatar({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final color = notification.type.color;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(notification.type.icon, color: color, size: 24),
    );
  }
}

// ════════════════════════ UNREAD DOT ════════════════════════

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ════════════════════════ PILL BUTTON ════════════════════════

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.border, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
