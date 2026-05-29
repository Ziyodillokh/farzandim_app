// ─────────────────────────────────────────────────────────────────────
// NotificationCard — bitta bildirishnoma elementi
// ─────────────────────────────────────────────────────────────────────
//
// Layout:
//   ┌────────────────────────────────────┐
//   │ [icon] Title              ●     │   ← ● = o'qilmagan dot
//   │        Body matn...               │
//   │        N daq oldin                │
//   └────────────────────────────────────┘

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(AppIcons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDismiss();
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? AppColors.surface
                // ignore: deprecated_member_use
                : notification.type.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: notification.isRead
                ? null
                : Border.all(
                    // ignore: deprecated_member_use
                    color: notification.type.color.withOpacity(0.3),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: notification.type.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notification.type.icon,
                  color: notification.type.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: notification.type.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: const TextStyle(
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'notifications.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'notifications.minutesAgo'
          .tr(namedArgs: {'min': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'notifications.hoursAgo'
          .tr(namedArgs: {'h': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return 'notifications.daysAgo'
          .tr(namedArgs: {'d': '${diff.inDays}'});
    }
    return DateFormat.yMd().format(dt);
  }
}
