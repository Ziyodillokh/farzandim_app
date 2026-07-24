// ─────────────────────────────────────────────────────────────────────
// Bildirishnomalar — pastdan ochiladigan panel (Figma 1:1, Parvoz night)
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilishi (Figma):
//   • Tutqich + markazda "Bildirishnomalar" sarlavhasi
//   • Sana bo'limlari: "Bugun" / "Kecha" / "12.02.2026" + ingichka chiziq
//   • SOS karta (qizil): "SOS xabar" + izoh + qizil chevron
//   • Oddiy qatorlar: dumaloq shisha ikon + sarlavha + izoh
//   • Pastda to'liq enli "Yopish" tugmasi
//
// Qo'ng'iroqcha bosilganda `showNotificationsSheet(context)` — oldingi
// sahifa orqada ko'rinib turadi (Figma). `/notifications` route esa shu
// kontentni to'liq sahifa qilib ochadi (deep-link/FCM uchun).
//
// Real: notificationsProvider (+ o'qildi/o'chirish amallari). Bo'sh
// bo'lsa PREVIEW (Figma'dagi qatorlar). LOGIKA SAQLANGAN: tap →
// markAsRead + relatedRoute, swipe → o'chirish.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _sheet = Color(0xFF12151B);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _line = Color(0x14FFFFFF);
const _red = Color(0xFFE74C4C);
const _aqua = Color(0xFF16B5C9); // brend (primary CTA)

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

/// Qo'ng'iroqcha bosilganda — pastdan ochiladigan panel (Figma).
void showNotificationsSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _sheet,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.86,
      child: const _NotifContent(showHandle: true),
    ),
  );
}

/// Bitta bildirishnoma detali — pastdan ochiladi. Rasm (bo'lsa), to'liq
/// sarlavha/matn, vaqt va (havola bo'lsa) "Ochish" tugmasi. Foydalanuvchi
/// bildirishnoma ustiga bosganda ochiladi — bu yerda banner rasm ko'rinadi.
void showNotifDetailSheet(BuildContext context, AppNotification n) {
  HapticFeedback.selectionClick();
  final route = n.relatedRoute;
  final hasRoute = route != null && route.trim().isNotEmpty;
  final img = n.imageUrl?.trim() ?? '';
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _sheet,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
      final maxImgH = MediaQuery.sizeOf(ctx).height * 0.4;
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 24),
              // Tur ikoni (rangli tayl).
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: n.type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: n.type.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(n.type.icon, size: 34, color: n.type.color),
              ),
              const SizedBox(height: 18),
              Text(
                n.title.isNotEmpty
                    ? n.title
                    : 'notifications.fallbackTitle'.tr(),
                textAlign: TextAlign.center,
                style: _unb(18),
              ),
              if (n.body.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  n.body.trim(),
                  textAlign: TextAlign.center,
                  style: _pop(14, c: _dim),
                ),
              ],
              // Banner rasm — admin bildirishnomani rasm bilan yuborsa.
              if (img.isNotEmpty) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxImgH),
                    child: CachedNetworkImage(
                      imageUrl: img,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: _glass,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      // Rasm yuklanmasa jimgina yashiramiz.
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _relativeTime(n.createdAt),
                style: _pop(12, c: const Color(0x66FFFFFF)),
              ),
              const SizedBox(height: 22),
              if (hasRoute) ...[
                _PillButton(
                  label: 'common.open'.tr(),
                  primary: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push(route.trim());
                  },
                ),
                const SizedBox(height: 10),
              ],
              _PillButton(
                label: 'common.close'.tr(),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Nisbiy vaqt matni: "hozir", "5 daq oldin", "3 soat oldin", "2 kun oldin"
/// yoki sana.
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'notifications.justNow'.tr();
  if (diff.inMinutes < 60) {
    return 'notifications.minutesAgo'.tr(
      namedArgs: {'min': '${diff.inMinutes}'},
    );
  }
  if (diff.inHours < 24) {
    return 'notifications.hoursAgo'.tr(namedArgs: {'h': '${diff.inHours}'});
  }
  if (diff.inDays < 7) {
    return 'notifications.daysAgo'.tr(namedArgs: {'d': '${diff.inDays}'});
  }
  return DateFormat('dd.MM.yyyy').format(dt);
}

/// `/notifications` route — xuddi shu kontent, to'liq sahifa (deep-link).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: _NotifContent(showHandle: false)),
    );
  }
}

// ════════════ Kontent (panel ham, sahifa ham shu) ════════════

class _NotifContent extends ConsumerWidget {
  const _NotifContent({required this.showHandle});
  final bool showHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(notificationsProvider);
    final items = itemsAsync.valueOrNull ?? const <AppNotification>[];
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Column(
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('notifications.title'.tr(), style: _unb(17)),
        const SizedBox(height: 8),
        Expanded(
          child: itemsAsync.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                )
              : items.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: _realRows(context, ref, items),
                ),
        ),
        // ── Yopish ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 14 + bottomInset),
          child: GestureDetector(
            onTap: () {
              if (showHandle) {
                Navigator.of(context).pop();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _glass,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _glassBorder),
              ),
              child: Text(
                'common.close'.tr(),
                style: _pop(15, w: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── REAL qatorlar: sana bo'limlari + tap (o'qildi) + swipe (o'chirish) ──
  List<Widget> _realRows(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    final now = DateTime.now();
    final rows = <Widget>[];
    String? lastSection;
    for (final n in items) {
      final section = DateUtils.isSameDay(n.createdAt, now)
          ? 'notifications.sectionToday'.tr()
          : DateUtils.isSameDay(
              n.createdAt,
              now.subtract(const Duration(days: 1)),
            )
          ? 'notifications.sectionYesterday'.tr()
          : DateFormat('dd.MM.yyyy').format(n.createdAt);
      if (section != lastSection) {
        lastSection = section;
        rows.add(_SectionLabel(label: section));
      }
      rows.add(
        Dismissible(
          key: ValueKey(n.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            HapticFeedback.lightImpact();
            ref
                .read(backendNotificationRepositoryProvider)
                .deleteNotification(n.id)
                .then((_) => ref.invalidate(notificationsProvider));
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline_rounded, color: _red),
          ),
          child: _NotifRow(
            icon: n.type.icon,
            imageUrl: n.imageUrl,
            title: n.title.isNotEmpty
                ? n.title
                : 'notifications.fallbackTitle'.tr(),
            subtitle: n.body,
            dimmed: n.isRead,
            onTap: () {
              HapticFeedback.selectionClick();
              if (!n.isRead) {
                ref
                    .read(backendNotificationRepositoryProvider)
                    .markAsRead(n.id)
                    .then((_) => ref.invalidate(notificationsProvider));
              }
              final hasImage = (n.imageUrl ?? '').trim().isNotEmpty;
              final route = n.relatedRoute;
              // Rasmsiz, faqat havolali (nudge/deepLink) → to'g'ridan bo'limga.
              // Aks holda (rasm bor yoki havolasiz) → detal: rasm + to'liq matn.
              if (!hasImage && route != null && route.isNotEmpty) {
                context.push(route);
              } else {
                showNotifDetailSheet(context, n);
              }
            },
          ),
        ),
      );
    }
    return rows;
  }

  // ── Bo'sh holat: hali bildirishnoma yo'q ──
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            'notifications.emptyTitle'.tr(),
            textAlign: TextAlign.center,
            style: _unb(16),
          ),
          const SizedBox(height: 8),
          Text(
            'notifications.emptySubtitle'.tr(),
            textAlign: TextAlign.center,
            style: _pop(13, c: Colors.white54),
          ),
        ],
      ),
    );
  }
}

// ════════════ Bo'lim yorlig'i: "Bugun ────────" ════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
      child: Row(
        children: [
          Text(label, style: _pop(12.5, c: _dim)),
          const SizedBox(width: 12),
          const Expanded(
            child: SizedBox(height: 1, child: ColoredBox(color: _line)),
          ),
        ],
      ),
    );
  }
}

// ════════════ Bildirishnoma qatori ════════════

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.dimmed = false,
    this.onTap,
  });

  final IconData icon;

  /// Rasmli xabar uchun thumbnail (ikon o'rniga). `null` = ikon.
  final String? imageUrl;
  final String title;
  final String subtitle;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _glass,
                  border: Border.all(color: _glassBorder),
                ),
                child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!.trim(),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(icon, color: Colors.white, size: 18),
                      )
                    : Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(13.5, w: FontWeight.w600, ls: -0.2),
                    ),
                    const SizedBox(height: 3),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(12.5, c: _dim),
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

// ════════════ Detal varaq tugmasi (pill) ════════════

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? _aqua : _glass,
          borderRadius: BorderRadius.circular(999),
          border: primary ? null : Border.all(color: _glassBorder),
        ),
        child: Text(
          label,
          style: _pop(
            15,
            w: FontWeight.w600,
            c: primary ? const Color(0xFF00131A) : Colors.white,
          ),
        ),
      ),
    );
  }
}
