// ─────────────────────────────────────────────────────────────────────
// notifications_providers — Backend Notifications (Sprint 4.4.9.5)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore stream → Backend REST. Yangilanish (1.0.20):
//   • WS `notification:created/read/read-all/deleted` — darhol;
//   • ilova ekranda bo'lsa 2 daqiqalik zaxira so'rov; fonda so'rov yo'q;
//   • ekranlar yopilsa provider ham yopiladi (autoDispose);
//   • tarmoq xatosi oxirgi ro'yxat va nishonni o'chirmaydi.

import 'dart:async';

import 'package:farzandim_child/app/app_lifecycle_provider.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/notifications_poller.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backend bola xonasiga yuboradigan bildirishnoma hodisalari.
const kNotificationEvents = [
  'notification:created',
  'notification:read',
  'notification:read-all',
  'notification:deleted',
];

/// Bola notifications + unreadCount — Backend fetch + WS + zaxira so'rov.
final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) {
    final childId = ref.watch(
      pairingStateProvider.select((p) => p.isPaired ? p.childId : null),
    );
    if (childId == null) return Stream.value(const <AppNotification>[]);

    final repo = ref.watch(backendNotificationRepositoryProvider);
    final poller = NotificationsPoller(
      fetch: () async {
        final result = await repo.getNotifications(childId: childId);
        if (result == null) return null;
        return [
          for (final n in result.items)
            if (!isHiddenMediaNotification(n)) n,
        ];
      },
    );
    ref.onDispose(poller.dispose);

    // Server hodisalari — yangi xabar / o'qildi / o'chirildi.
    final socket = ref.watch(socketClientProvider);
    for (final event in kNotificationEvents) {
      final sub = socket
          .eventStream(event)
          .listen((_) => unawaited(poller.refresh()));
      ref.onDispose(sub.cancel);
    }

    // Faqat ilova ekranda bo'lganda (qaytganda — darhol yangilanadi).
    ref.listen<bool>(
      isAppInForegroundProvider,
      (_, isForeground) => poller.setActive(isForeground),
      fireImmediately: true,
    );
    return poller.stream;
  },
);

/// O'qilmagan soni (Backend `/notifications` response unreadCount).
final unreadNotificationsCountProvider = Provider.autoDispose<AsyncValue<int>>((
  ref,
) {
  return ref
      .watch(notificationsProvider)
      .whenData((list) => list.where((n) => !n.isRead).length);
});

/// Tab filter.
enum NotificationTab { all, unread }

final notificationTabProvider = StateProvider<NotificationTab>(
  (_) => NotificationTab.all,
);

/// Filtrlangan notifications (UI derived).
final filteredNotificationsProvider =
    Provider.autoDispose<List<AppNotification>>((ref) {
      final tab = ref.watch(notificationTabProvider);
      final all = ref.watch(notificationsProvider).valueOrNull ?? const [];
      switch (tab) {
        case NotificationTab.all:
          return all;
        case NotificationTab.unread:
          return all.where((n) => !n.isRead).toList();
      }
    });

/// Audio / video haqidagi bildirishnoma (kontent eslatmasi yoki shunday
/// havola) — yashirin paytda ro'yxatda ham, o'qilmaganlar sonida ham yo'q.
bool isHiddenMediaNotification(AppNotification n) =>
    !kShowAudioVideo &&
    (n.type == NotificationType.contentReminder ||
        isHiddenMediaRoute(n.relatedRoute));
