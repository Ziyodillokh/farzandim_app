// ─────────────────────────────────────────────────────────────────────
// NotificationCard — bitta bildirishnoma (yorug' dizayn, rasm bilan)
// ─────────────────────────────────────────────────────────────────────
//
// Layout (yuqoridan pastga, toza tekislangan):
//   ┌────────────────────────────────────┐
//   │ Yangi o'yin qo'shildi          ●  │ ← kichik kulrang sarlavha + unread
//   │ Asosiy matn (qora) ...             │
//   │ ┌────────────────────────────────┐ │
//   │ │      rasm (ixtiyoriy)          │ │ ← thumbnailUrl bo'lsa
//   │ └────────────────────────────────┘ │
//   │ 2 daqiqa oldin                     │
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

  static const Color _imgFallbackA = Color(0xFF5B6CFF);
  static const Color _imgFallbackB = Color(0xFF8E5BFF);

  bool get _hasImage =>
      notification.thumbnailUrl != null &&
      notification.thumbnailUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final accent = notification.type.color;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(18),
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: unread
                ? accent.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.28)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sarlavha (kichik kulrang) + unread nuqta ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Asosiy matn (qora) ──
              Text(
                notification.body,
                maxLines: _hasImage ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

              // ── Rasm (ixtiyoriy) ──
              if (_hasImage) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 8.5,
                    child: Image.network(
                      notification.thumbnailUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _imageFallback(),
                      errorBuilder: (_, __, ___) => _imageFallback(),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ── Vaqt ──
              Text(
                _timeAgo(notification.createdAt),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_imgFallbackA, _imgFallbackB],
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
      return 'notifications.hoursAgo'.tr(namedArgs: {'h': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return 'notifications.daysAgo'.tr(namedArgs: {'d': '${diff.inDays}'});
    }
    return DateFormat.yMd().format(dt);
  }
}
