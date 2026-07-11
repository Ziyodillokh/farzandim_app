// ─────────────────────────────────────────────────────────────────────
// notifications_providers — Backend Notifications (Sprint 4.4.9.5)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore stream → Backend REST + polling.
// Child App'da Socket.io yo'q hozir — polling 15 sek bilan kompensatsiya.

import 'dart:async';

import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola notifications + unreadCount — Backend fetch + polling.
final notificationsProvider = StreamProvider<List<AppNotification>>((
  ref,
) async* {
  final pairing = ref.watch(pairingStateProvider);
  if (!pairing.isPaired || pairing.childId == null) {
    yield const [];
    return;
  }

  final repo = ref.watch(backendNotificationRepositoryProvider);
  final controller = StreamController<List<AppNotification>>();

  Future<void> fetch() async {
    if (controller.isClosed) return;
    final result = await repo.getNotifications(childId: pairing.childId!);
    if (!controller.isClosed) controller.add(result.items);
  }

  await fetch(); // initial
  final timer = Timer.periodic(const Duration(seconds: 15), (_) => fetch());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  yield* controller.stream;
});

/// O'qilmagan soni (Backend `/notifications` response unreadCount).
final unreadNotificationsCountProvider = Provider<AsyncValue<int>>((ref) {
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
final filteredNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final tab = ref.watch(notificationTabProvider);
  final all = ref.watch(notificationsProvider).valueOrNull ?? const [];
  switch (tab) {
    case NotificationTab.all:
      return all;
    case NotificationTab.unread:
      return all.where((n) => !n.isRead).toList();
  }
});
