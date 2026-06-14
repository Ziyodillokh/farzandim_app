// ─────────────────────────────────────────────────────────────────────
// NotificationCard — bitta bildirishnoma (dark, rasm bilan — mockup 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Layout (yuqoridan pastga):
//   ┌────────────────────────────────────┐
//   │ Yangi o'yin qo'shildi          ●  │ ← kichik kulrang sarlavha + unread
//   │ Asosiy matn (oq) ...               │
//   │ ┌────────────────────────────────┐ │
//   │ │      rasm (ixtiyoriy)          │ │ ← thumbnailUrl bo'lsa
//   │ └────────────────────────────────┘ │
//   │ 2 mins ago                         │
//   └────────────────────────────────────┘

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
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

  // Dark palitra — mockup'ga qat'iy mos (theme'dan mustaqil).
  static const Color _cardRead = Color(0xFF1E1E2A);
  static const Color _cardUnread = Color(0xFF232333);
  static const Color _titleGray = Color(0xFF9A9AB0);
  static const Color _bodyWhite = Color(0xFFEDEDF5);
  static const Color _timeGray = Color(0xFF6B6B80);
  static const Color _imgFallbackA = Color(0xFF5B6CFF);
  static const Color _imgFallbackB = Color(0xFF8E5BFF);

  bool get _hasImage =>
      notification.thumbnailUrl != null &&
      notification.thumbnailUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFE43A5C),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead ? _cardRead : _cardUnread,
            borderRadius: BorderRadius.circular(18),
            border: notification.isRead
                ? Border.all(color: Colors.white.withValues(alpha: 0.04))
                : Border.all(
                    color: notification.type.color.withValues(alpha: 0.35),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sarlavha (kichik kulrang) + unread nuqta ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _titleGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      decoration: BoxDecoration(
                        color: notification.type.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Asosiy matn (oq) ──
              Text(
                notification.body,
                maxLines: _hasImage ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _bodyWhite,
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
                  color: _timeGray,
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
