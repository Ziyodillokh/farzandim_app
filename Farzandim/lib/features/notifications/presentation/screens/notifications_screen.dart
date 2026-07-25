// Bildirishnomalar to'liq sahifasi (Parvoz). Bu route FCM push bosilganda
// va Sozlamalar'dan ochiladi (deep-link). Dashboard qo'ng'irog'i esa
// `NotificationsSheet` orqali ochadi. Ikkalasi ham `NotificationsListView`
// (kunlik guruhlangan) va bosilganda: SOS -> SOS modali, aks holda detal.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/screens/sos_sheet.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notifications_list_view.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _bg = Color(0xFF00060A);
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

/// Bildirishnomalar to'liq sahifasi (route target).
class NotificationsScreen extends ConsumerWidget {
  /// `NotificationsScreen` konstruktor.
  const NotificationsScreen({super.key});

  void _onTap(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markAsRead(n.id);
    // Chat xabari (ovozli/matn/video) — avval bu holat umuman
    // ko'rilmagan edi, generik "detal" ekraniga ochilardi. `senderId`
    // (bola userId) bo'yicha bolani topib to'g'ridan-to'g'ri chatga.
    final chatType = n.data?['type'];
    if (chatType == 'voice' || chatType == 'video') {
      final senderId = n.data?['senderId'] as String?;
      for (final c in ref.read(childrenListProvider)) {
        if (c.linkedDeviceUid == senderId) {
          context
            ..go(AppRoutes.dashboard)
            ..push(AppRoutes.qaVoicePath(c.id));
          return;
        }
      }
    }
    if (n.type == NotificationType.sos) {
      // SOS bosilса — xaritali "SOS xabar" modali (bola joyi + Manzil + Qachon
      // + Telefon qilish / Xabar yozish). Avval SosAlertsListScreen (ro'yxat)
      // ochilardi — foydalanuvchi talabiga ko'ra qaytadan shu modal.
      unawaited(SosSheet.show(context, n));
    } else {
      context.push(AppRoutes.notificationDetail, extra: n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            const SizedBox(height: 6),
            Expanded(
              child: items.isEmpty
                  ? const _Empty()
                  : NotificationsListView(
                      items: items,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      onTap: (n) => _onTap(context, ref, n),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Sarlavha ════════════
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ParvozBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                'notifications.listTitle'.tr(),
                style: _unb(20, w: FontWeight.w500, ls: -0.6),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
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
            padding: const EdgeInsets.symmetric(horizontal: 40),
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
