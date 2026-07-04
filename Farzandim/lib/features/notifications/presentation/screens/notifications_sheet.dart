// "Bildirishnomalar" tortiladigan varaq (Parvoz, rasm 3). Dashboard'dagi
// qo'ng'iroq ikonidan ochiladi. Xabarni bossa — o'qilgan deb belgilanadi,
// varaq yopiladi va o'sha xabar detal sahifasi ochiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notification_row.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _sheetBg = Color(0xFF12171E);
const _cardBorder = Color(0x14FFFFFF);
const _divider = Color(0x14FFFFFF);
const _dim = Color(0x99FFFFFF); // oq 60%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.45,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// SOS eng tepada, keyin vaqt bo'yicha yangi→eski.
List<AppNotification> _sorted(List<AppNotification> list) {
  final items = [...list]
    ..sort((a, b) {
      final aSos = a.type == NotificationType.sos ? 0 : 1;
      final bSos = b.type == NotificationType.sos ? 0 : 1;
      if (aSos != bSos) return aSos - bSos;
      return b.timestamp.compareTo(a.timestamp);
    });
  return items;
}

/// Bildirishnomalar varag'i.
class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet._();

  /// Varaqni ochadi; xabar bosilsa — o'sha xabar detal sahifasiga o'tadi.
  static Future<void> show(BuildContext context) async {
    final tapped = await showModalBottomSheet<AppNotification>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const NotificationsSheet._(),
    );
    if (tapped != null && context.mounted) {
      await context.push(AppRoutes.notificationDetail, extra: tapped);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _sorted(ref.watch(notificationsProvider));
    final h = MediaQuery.sizeOf(context).height;

    return Container(
      height: h * 0.8,
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              // Tortish dastagi
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text('notifications.listTitle'.tr(), style: _unb(17)),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: _divider,
                        ),
                        itemBuilder: (context, i) {
                          final n = items[i];
                          return NotificationRow(
                            notification: n,
                            onTap: () {
                              ref
                                  .read(notificationsProvider.notifier)
                                  .markAsRead(n.id);
                              Navigator.of(context).pop(n);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ParvozSecondaryButton(
                label: 'common.close'.tr(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Bo'sh holat ════════════
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Icon(
              SolarIconsBold.mailbox,
              size: 58,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text('notifications.emptyTitle'.tr(), style: _unb(15)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'notifications.emptySubtitle'.tr(),
              textAlign: TextAlign.center,
              style: _pop(13, c: _dim),
            ),
          ),
        ],
      ),
    );
  }
}
