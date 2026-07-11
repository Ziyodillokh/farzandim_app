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

import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _sheet = Color(0xFF12151B);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _line = Color(0x14FFFFFF);
const _red = Color(0xFFE74C4C);

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
        Text('Bildirishnomalar', style: _unb(17)),
        const SizedBox(height: 8),
        Expanded(
          child: itemsAsync.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: items.isEmpty
                      ? _previewRows(context)
                      : _realRows(context, ref, items),
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
              child: Text('Yopish', style: _pop(15, w: FontWeight.w600)),
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
          ? 'Bugun'
          : DateUtils.isSameDay(
              n.createdAt,
              now.subtract(const Duration(days: 1)),
            )
          ? 'Kecha'
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
            title: n.title.isNotEmpty ? n.title : 'Bildirishnoma',
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
              final route = n.relatedRoute;
              if (route != null && route.isNotEmpty) context.push(route);
            },
          ),
        ),
      );
    }
    return rows;
  }

  // ── PREVIEW qatorlar — Figma'dagi ro'yxat 1:1 ──
  List<Widget> _previewRows(BuildContext context) {
    return [
      const _SectionLabel(label: 'Bugun'),
      const SizedBox(height: 4),
      // SOS karta (Figma).
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(_red.withValues(alpha: 0.12), _sheet),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOS xabar', style: _unb(15, c: _red)),
                  const SizedBox(height: 3),
                  Text(
                    'Akmaldan xabar oling!',
                    style: _pop(12.5, c: _red.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _red, size: 26),
          ],
        ),
      ),
      const SizedBox(height: 6),
      const _NotifRow(
        icon: Icons.keyboard_double_arrow_up_rounded,
        title: 'Ilovada yangilanish mavjud',
        subtitle: 'Ilovaning yangi versiyasi chiqti',
      ),
      const _NotifRow(
        icon: Icons.priority_high_rounded,
        title: 'Akmal bloklangan ilovaga kirdi',
        subtitle: 'Ilovaning yangi versiyasi chiqti',
      ),
      const SizedBox(height: 8),
      const _SectionLabel(label: '12.02.2026'),
      const _NotifRow(
        icon: Icons.priority_high_rounded,
        title: "Akmal bilan aloqa yo'qoldi",
        subtitle: 'Ilovaning yangi versiyasi chiqti',
      ),
      const _NotifRow(
        icon: Icons.menu_book_rounded,
        title: 'Akmal bugun bitta kitobni tugatti',
        subtitle: 'Ilovaning yangi versiyasi chiqti',
      ),
      const _NotifRow(
        icon: Icons.chat_bubble_rounded,
        title: 'Akmaldan xabar',
        subtitle: 'Assalomu alaykum!',
      ),
    ];
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
    this.dimmed = false,
    this.onTap,
  });

  final IconData icon;
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _glass,
                  border: Border.all(color: _glassBorder),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
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
