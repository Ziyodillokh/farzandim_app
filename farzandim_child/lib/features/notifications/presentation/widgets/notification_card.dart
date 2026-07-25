// ─────────────────────────────────────────────────────────────────────
// NotificationCard — premium, kategoriya-rangli bildirishnoma kartochkasi
// ─────────────────────────────────────────────────────────────────────
//
// Har tur o'z kimligiga ega: 46×46 soft badge + aksent ikona. O'qilmagan
// kartochkada chap aksent chizig'i (3.5px), kuchliroq soya va puls'lanuvchi
// nuqta. Bosilganda 0.978 ga siqiladi. prefers-reduced-motion hurmat qilinadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/notification_tokens.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationCard extends StatefulWidget {
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
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  bool get _unread => !widget.notification.isRead;

  bool get _hasImage =>
      widget.notification.thumbnailUrl != null &&
      widget.notification.thumbnailUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // prefers-reduced-motion: animatsiyani o'chiramiz.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_unread && !reduce) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final style = notifStyleFor(widget.notification.type);

    return Dismissible(
      key: ValueKey(widget.notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: NotifTokens.danger,
          borderRadius: BorderRadius.circular(NotifTokens.cardRadius),
        ),
        child: const Icon(AppIcons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.onDismiss();
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (!reduce) setState(() => _pressed = true);
        },
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.978 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: NotifTokens.surface,
              borderRadius: BorderRadius.circular(NotifTokens.cardRadius),
              boxShadow: _unread ? NotifTokens.shadowMd : NotifTokens.shadowSm,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: _content(style),
                ),
                // Chap aksent chizig'i — faqat o'qilmaganda.
                if (_unread)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: NotifTokens.unreadBar,
                    child: ColoredBox(color: style.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(NotifCategoryStyle style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 46×46 soft badge ──
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: style.soft,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(style.icon, color: style.accent, size: 23),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NotifTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (_unread) ...[
                    const SizedBox(width: 8),
                    _PulseDot(accent: style.accent, anim: _pulse),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.notification.body,
                maxLines: _hasImage ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NotifTokens.ink2,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.42,
                ),
              ),
              if (_hasImage) ...[
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 8.5,
                    child: Image.network(
                      widget.notification.thumbnailUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _imageFallback(style),
                      errorBuilder: (_, __, ___) => _imageFallback(style),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _fmtWhen(widget.notification.createdAt),
                style: const TextStyle(
                  color: NotifTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageFallback(NotifCategoryStyle style) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.accent, style.accent.withValues(alpha: 0.65)],
        ),
      ),
    );
  }

  /// Xabar kelgan ANIQ sana + soat: "Bugun, 17:54" / "Kecha, 17:54" /
  /// "25.07.2026, 17:54" (relative "2 soat oldin" o'rniga — foydalanuvchi
  /// aniq vaqtni ko'rishni so'radi).
  String _fmtWhen(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(l.hour)}:${two(l.minute)}';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(l.year, l.month, l.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) return '${'notifications.sectionToday'.tr()}, $time';
    if (diffDays == 1) {
      return '${'notifications.sectionYesterday'.tr()}, $time';
    }
    return '${two(l.day)}.${two(l.month)}.${l.year}, $time';
  }
}

/// O'qilmagan nuqta + nozik puls'lanuvchi halo.
class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.accent, required this.anim});
  final Color accent;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, child) {
            // 0..1 → halo 1.0→2.2 kattalashadi va so'nadi.
            final t = anim.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 1 + t * 1.2,
                  child: Opacity(
                    opacity: (1 - t) * 0.45,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
