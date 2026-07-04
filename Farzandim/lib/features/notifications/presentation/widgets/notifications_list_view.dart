// Bildirishnomalar ro'yxati — kunlik guruhlangan (Bugun / Kecha / sana),
// SOS xabari tepada maxsus qizil karta, qolganlari oddiy qator. Varaq va
// to'liq sahifa shu widgetni ulashadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notification_row.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _divider = Color(0x14FFFFFF); // oq ~8% ajratgich
const _dim = Color(0x99FFFFFF); // oq 60% — guruh sarlavhasi

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// Kun bo'yicha guruhlangan bildirishnomalar ro'yxati.
class NotificationsListView extends StatelessWidget {
  /// `NotificationsListView` konstruktor.
  const NotificationsListView({
    required this.items,
    required this.onTap,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Ko'rsatiladigan xabarlar (guruhlanadi).
  final List<AppNotification> items;

  /// Xabar (qator yoki SOS karta) bosilganda chaqiriladi.
  final ValueChanged<AppNotification> onTap;

  /// Ro'yxat paddingi.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(items);
    final children = <Widget>[];

    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      if (g > 0) children.add(const SizedBox(height: 20));
      children
        ..add(_GroupHeader(label: group.label))
        ..add(const SizedBox(height: 8));

      final sos = group.items
          .where((n) => n.type == NotificationType.sos)
          .toList();
      final rows = group.items
          .where((n) => n.type != NotificationType.sos)
          .toList();

      for (final n in sos) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SosNotificationCard(notification: n, onTap: () => onTap(n)),
          ),
        );
      }
      for (var i = 0; i < rows.length; i++) {
        final n = rows[i];
        children.add(NotificationRow(notification: n, onTap: () => onTap(n)));
        if (i < rows.length - 1) {
          children.add(const Divider(height: 1, thickness: 1, color: _divider));
        }
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: children,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: _pop(13, c: _dim)),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: _divider),
          ),
        ],
      ),
    );
  }
}

/// Xabarlarni kun bo'yicha guruhlaydi (yangi kun tepada), har guruh ichida
/// SOS eng oldinda, keyin vaqt bo'yicha yangi→eski.
List<({String label, List<AppNotification> items})> _groupByDay(
  List<AppNotification> items,
) {
  final byDay = <DateTime, List<AppNotification>>{};
  for (final n in items) {
    final d = DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
    (byDay[d] ??= <AppNotification>[]).add(n);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      (
        label: _dayLabel(day),
        items: byDay[day]!
          ..sort((a, b) {
            final aSos = a.type == NotificationType.sos ? 0 : 1;
            final bSos = b.type == NotificationType.sos ? 0 : 1;
            if (aSos != bSos) return aSos - bSos;
            return b.timestamp.compareTo(a.timestamp);
          }),
      ),
  ];
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'notifications.today'.tr();
  if (day == yesterday) return 'notifications.yesterday'.tr();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}.${two(day.month)}.${day.year}';
}
