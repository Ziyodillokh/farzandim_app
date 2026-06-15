// ─────────────────────────────────────────────────────────────────────
// NotificationsScreen — Stitch "Bildirishnomalar (Night)" + PREMIUM polish
// ─────────────────────────────────────────────────────────────────────
//
// UI Stitch dizayniga ko'chirildi; backend (notificationsProvider + polling)
// o'zi ulanib turadi. Premium qatlam:
//   • Suzuvchi glass header (haqiqiy BackdropFilter blur) — top-bar + tab'lar
//   • Type-rang medallion (turi ikonkasi) + o'qilgan↔o'qilmagan vizual farqi
//   • Sana guruhlash (Bugun / Kecha / Avvalroq)
//   • Staggered kirish animatsiyasi + bosilish scale + pull-to-refresh
//   • Skeleton shimmer yuklash + FARO maskotli bo'sh holat
// Night asosiy; light — sodda oq. Amallar: o'qilgan belgilash, swipe-o'chirish.

import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────── Stitch palette (notifications: primary #2ecc71) ───────────────

class _P {
  _P(this.dark);
  final bool dark;

  Color get bg => dark ? const Color(0xFF0B1C30) : const Color(0xFFF8F9FF);
  Color get card => dark ? const Color(0xFF162B45) : Colors.white;
  Color get text => dark ? Colors.white : const Color(0xFF0B1C30);
  Color get muted => dark ? const Color(0xFF94A3B8) : const Color(0xFF5A6B66);
  Color get green => const Color(0xFF2ECC71);
  Color get orange => const Color(0xFFF39C12);
  Color get red => const Color(0xFFE74C3C);
  Color get border => green.withValues(alpha: dark ? 0.20 : 0.30);
}

TextStyle _jak(
  _P p, {
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? p.text,
      height: height,
      letterSpacing: letterSpacing,
    );

String _relTime(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'Hozir';
  if (d.inMinutes < 60) return '${d.inMinutes} daqiqa avval';
  if (d.inHours < 24) return '${d.inHours} soat avval';
  if (d.inDays < 7) return '${d.inDays} kun avval';
  return '${dt.day}.${dt.month}.${dt.year}';
}

// ─────────────── SCREEN ───────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = _P(context.adaptive.isDark);
    final allAsync = ref.watch(notificationsProvider);
    final filtered = ref.watch(filteredNotificationsProvider);
    // Suzuvchi glass header balandligi (statusbar + top-bar + tab'lar).
    final topPad = MediaQuery.paddingOf(context).top + 132;

    return Scaffold(
      backgroundColor: p.bg,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: allAsync.when(
              data: (_) => _Body(p: p, items: filtered, topPad: topPad, onRefresh: () => _refresh(ref)),
              loading: () => _SkeletonList(p: p, topPad: topPad),
              error: (e, _) => Padding(
                padding: EdgeInsets.fromLTRB(24, topPad + 40, 24, 0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text('common.errorPrefix'.tr(namedArgs: {'error': '$e'}),
                      textAlign: TextAlign.center, style: _jak(p, color: p.red)),
                ),
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _GlassHeader(p: p)),
        ],
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    ref.invalidate(notificationsProvider);
    await ref.read(notificationsProvider.future);
  }
}

// ─────────────── BODY (guruhlangan ro'yxat + pull-to-refresh) ───────────────

class _Body extends ConsumerWidget {
  const _Body({required this.p, required this.items, required this.topPad, required this.onRefresh});
  final _P p;
  final List<AppNotification> items;
  final double topPad;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: p.green,
        backgroundColor: p.card,
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (ctx, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: EdgeInsets.only(top: topPad),
                child: EmptyStateMascot(
                  faroVariant: FaroVariant.faceSleeping,
                  accentColor: p.green,
                  title: 'notifications.emptyTitle'.tr(),
                  subtitle: 'notifications.emptySubtitle'.tr(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final rows = _group(items);
    return RefreshIndicator(
      color: p.green,
      backgroundColor: p.card,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          if (row.notification == null) return _SectionHeader(p: p, label: row.label!);
          final n = row.notification!;
          return _NotificationCard(
            p: p,
            notification: n,
            cardIndex: row.cardIndex,
            onTap: () => _onTap(context, ref, n),
            onDismiss: () => _onDismiss(ref, n.id),
          );
        },
      ),
    );
  }

  // createdAt bo'yicha 3 bucket — tartib saqlanadi (eng yangisi tepada).
  List<_Row> _group(List<AppNotification> list) {
    final now = DateTime.now();
    final today = <AppNotification>[], yest = <AppNotification>[], earlier = <AppNotification>[];
    for (final n in list) {
      if (DateUtils.isSameDay(n.createdAt, now)) {
        today.add(n);
      } else if (DateUtils.isSameDay(n.createdAt, now.subtract(const Duration(days: 1)))) {
        yest.add(n);
      } else {
        earlier.add(n);
      }
    }
    final rows = <_Row>[];
    var idx = 0;
    void add(String label, List<AppNotification> b) {
      if (b.isEmpty) return;
      rows.add(_Row.header(label));
      for (final n in b) {
        rows.add(_Row.card(n, idx));
        idx++;
      }
    }

    add('Bugun', today);
    add('Kecha', yest);
    add('Avvalroq', earlier);
    return rows;
  }

  void _onTap(BuildContext context, WidgetRef ref, AppNotification n) {
    HapticFeedback.selectionClick();
    final repo = ref.read(backendNotificationRepositoryProvider);
    if (!n.isRead) {
      repo.markAsRead(n.id).then((_) => ref.invalidate(notificationsProvider));
    }
    final route = n.relatedRoute;
    if (route != null && route.isNotEmpty) context.push(route);
  }

  void _onDismiss(WidgetRef ref, String id) {
    HapticFeedback.lightImpact();
    ref.read(backendNotificationRepositoryProvider).deleteNotification(id).then((_) => ref.invalidate(notificationsProvider));
  }
}

/// Ro'yxat satri — sarlavha (header) yoki karta (card).
class _Row {
  const _Row.header(this.label)
      : notification = null,
        cardIndex = -1;
  const _Row.card(AppNotification this.notification, this.cardIndex) : label = null;
  final String? label;
  final AppNotification? notification;
  final int cardIndex;
}

// ─────────────── GLASS HEADER (suzuvchi, blur) ───────────────

class _GlassHeader extends StatelessWidget {
  const _GlassHeader({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: p.bg.withValues(alpha: p.dark ? 0.72 : 0.82),
            border: Border(bottom: BorderSide(color: p.border, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(p: p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _FilterTabs(p: p),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────── TOP BAR ───────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: p.green, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Text('Parvoz', style: _jak(p, size: 20, weight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/dashboard'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: p.red,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(color: p.red.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 17),
                  const SizedBox(width: 4),
                  Text('SOS', style: _jak(p, size: 13, weight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, color: p.muted, size: 24),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

// ─────────────── FILTER TABS (o'qilmaganlar soni bilan) ───────────────

class _FilterTabs extends ConsumerWidget {
  const _FilterTabs({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(notificationTabProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              p: p,
              label: 'notifications.tabAll'.tr(),
              active: active == NotificationTab.all,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(notificationTabProvider.notifier).state = NotificationTab.all;
              },
            ),
          ),
          Expanded(
            child: _Tab(
              p: p,
              label: 'notifications.tabUnread'.tr(),
              active: active == NotificationTab.unread,
              badge: unread,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(notificationTabProvider.notifier).state = NotificationTab.unread;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.p, required this.label, required this.active, required this.onTap, this.badge = 0});
  final _P p;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? p.green : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _jak(p, size: 14, weight: FontWeight.w600, color: active ? Colors.white : p.muted)),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.25) : p.orange,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$badge',
                    textAlign: TextAlign.center,
                    style: _jak(p, size: 10, weight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────── SECTION HEADER (Bugun / Kecha / Avvalroq) ───────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.p, required this.label});
  final _P p;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(label.toUpperCase(), style: _jak(p, size: 12, weight: FontWeight.w700, color: p.muted, letterSpacing: 0.6)),
    );
  }
}

// ─────────────── CARD ───────────────

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.p,
    required this.notification,
    required this.cardIndex,
    required this.onTap,
    required this.onDismiss,
  });
  final _P p;
  final AppNotification notification;
  final int cardIndex;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final n = widget.notification;
    final unread = !n.isRead;

    final cardColor = unread
        ? Color.alphaBlend(p.green.withValues(alpha: p.dark ? 0.06 : 0.035), p.card)
        : p.card;
    final borderColor = unread ? p.green.withValues(alpha: 0.30) : p.border;

    final card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: (p.dark ? Colors.black : const Color(0xFF0B1C30)).withValues(alpha: p.dark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
          if (unread)
            BoxShadow(color: p.green.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type-rang medallion.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n.type.color.withValues(alpha: unread ? 0.16 : 0.10),
                border: unread ? Border.all(color: n.type.color.withValues(alpha: 0.32), width: 1) : null,
              ),
              child: Icon(n.type.icon, color: n.type.color.withValues(alpha: unread ? 1 : 0.55), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (unread) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: p.orange, borderRadius: BorderRadius.circular(5)),
                          child: Text('Yangi', style: _jak(p, size: 10, weight: FontWeight.w800, color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          n.title.isNotEmpty ? n.title : n.type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _jak(p,
                              size: 15,
                              weight: unread ? FontWeight.w700 : FontWeight.w600,
                              color: unread ? p.text : p.muted,
                              letterSpacing: -0.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(_relTime(n.createdAt),
                            style: _jak(p, size: 11.5, weight: FontWeight.w500, color: p.muted.withValues(alpha: 0.7))),
                      ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _jak(p, size: 13.5, weight: FontWeight.w400, color: p.muted, height: 1.45)),
                  ],
                  if (n.thumbnailUrl != null && n.thumbnailUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 8,
                        child: Image.network(n.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: n.type.color.withValues(alpha: 0.2))),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final dismissible = Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(color: p.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.delete_outline_rounded, color: p.red),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Opacity(
          opacity: unread ? 1 : 0.72,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: card,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: dismissible,
    ).animate().fadeIn(
          duration: 300.ms,
          delay: ((widget.cardIndex % 8) * 40).ms,
        ).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic, duration: 300.ms);
  }
}

// ─────────────── SKELETON SHIMMER (yuklash) ───────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.p, required this.topPad});
  final _P p;
  final double topPad;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 120),
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(6, (_) => _SkeletonCard(p: p)),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context) {
    final block = p.muted.withValues(alpha: 0.12);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: block)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140, 13),
                const SizedBox(height: 10),
                bar(double.infinity, 11),
                const SizedBox(height: 6),
                bar(200, 11),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: p.muted.withValues(alpha: 0.08));
  }
}

// `NotificationType.label` — sarlavha bo'sh bo'lsa fallback nom.
extension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.achievement:
        return 'Yangi yutuq';
      case NotificationType.contest:
        return 'Konkurs';
      case NotificationType.schedule:
        return 'Jadval eslatmasi';
      case NotificationType.parentRequest:
        return 'Ota-ona so\'rovi';
      case NotificationType.voice:
        return 'Yangi xabar';
      case NotificationType.geoZone:
        return 'Joylashuv';
      case NotificationType.system:
        return 'Tizim xabari';
      case NotificationType.studyNudge:
        return 'Dars eslatmasi';
      case NotificationType.healthNudge:
        return 'Harakat eslatmasi';
      case NotificationType.contentReminder:
        return 'Yangi kontent';
    }
  }
}
