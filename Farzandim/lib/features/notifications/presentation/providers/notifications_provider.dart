// ─────────────────────────────────────────────────────────────────────
// notifications_provider — Local persistence + filter (Sprint 4.4.21)
// ─────────────────────────────────────────────────────────────────────
//
// FCM dan kelgan xabarlar SharedPreferences'ga saqlanadi va app restart
// bo'lganda tiklanadi. Max 100 ta xabar saqlanadi (eng yangilari).

import 'dart:async';
import 'dart:convert';

import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'notifications_history_v1';
const _maxStored = 100;

/// Fonda kelgan FCM push'lar (bg isolate, `main.dart` background handler)
/// yoziladigan "pending" navbat kaliti — `syncPending()` shu yerdan o'qiydi.
const kPendingNotificationsPrefsKey = 'notifications_pending_v1';

/// Bildirishnomalar ro'yxatini boshqaruvchi notifier.
///
/// - FCM payload orqali `addFromFcm` chaqiriladi (foreground)
/// - Fonda kelgan push'lar bg isolate "pending" navbatiga yoziladi —
///   startup va har app-resume'da `syncPending()` ularni qo'shib oladi
/// - Har mutation SharedPreferences'ga saqlanadi
/// - App startup'da `_load()` orqali tiklanadi
class NotificationsNotifier extends StateNotifier<List<AppNotification>>
    with WidgetsBindingObserver {
  /// `NotificationsNotifier` konstruktor — yuklash boshlanadi darhol.
  NotificationsNotifier() : super(const []) {
    _load();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foydalanuvchi ilovaga qaytdi — fonda kelgan push'larni ro'yxatga olamiz.
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPending());
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .whereType<AppNotification>()
            .toList();
        if (list.isNotEmpty) state = list;
      }
    } catch (e) {
      debugPrint('NotificationsNotifier._load: $e');
    }
    await syncPending();
  }

  /// Fonda (bg isolate) kelgan push'larni pending navbatdan ro'yxatga
  /// ko'chirish. Dedup `id` (FCM messageId) bo'yicha — tap orqali allaqachon
  /// qo'shilgan xabar takrorlanmaydi.
  Future<void> syncPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bg isolate yozganini ko'rish uchun reload shart.
      await prefs.reload();
      final raw = prefs.getString(kPendingNotificationsPrefsKey);
      if (raw == null || raw.isEmpty) return;
      await prefs.remove(kPendingNotificationsPrefsKey);

      final items = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .whereType<AppNotification>()
          .toList();
      if (items.isEmpty) return;

      final existing = state.map((n) => n.id).toSet();
      final fresh =
          items.where((n) => !existing.contains(n.id)).toList();
      if (fresh.isEmpty) return;

      // Pending eski→yangi tartibda — yangilari ro'yxat tepasiga chiqsin.
      state = [...fresh.reversed, ...state];
      if (state.length > _maxStored) {
        state = state.sublist(0, _maxStored);
      }
      unawaited(_persist());
    } catch (e) {
      debugPrint('NotificationsNotifier.syncPending: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = state.length > _maxStored
          ? state.sublist(0, _maxStored)
          : state;
      final encoded = jsonEncode(capped.map((n) => n.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('NotificationsNotifier._persist: $e');
    }
  }

  /// Bitta xabarni o'qilgan deb belgilash.
  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id && !n.isRead) n.copyWith(isRead: true) else n,
    ];
    unawaited(_persist());
  }

  /// Hammasini o'qilgan deb belgilash.
  void markAllAsRead() {
    state = [
      for (final n in state)
        if (!n.isRead) n.copyWith(isRead: true) else n,
    ];
    unawaited(_persist());
  }

  /// Xabarni ro'yxatdan o'chirish (Dismissible swipe orqali).
  void deleteNotification(String id) {
    state = state.where((n) => n.id != id).toList();
    unawaited(_persist());
  }

  /// Hamma xabarlarni o'chirish.
  void clearAll() {
    state = const [];
    unawaited(_persist());
  }

  /// FCM dan kelgan xabarni ro'yxatga qo'shadi.
  void addFromFcm(AppNotification notification) {
    if (state.any((n) => n.id == notification.id)) return;
    state = [notification, ...state];
    if (state.length > _maxStored) {
      state = state.sublist(0, _maxStored);
    }
    unawaited(_persist());
  }
}

/// Bildirishnomalar provider'i.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  (ref) => NotificationsNotifier(),
);

/// O'qilmagan xabarlar soni — Dashboard bell badge uchun.
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

/// Filter guruhlari — UI tabs.
enum NotificationFilter {
  /// Hamma xabarlar.
  all,

  /// Faqat SOS.
  sos,

  /// Geo-zona (kirish/chiqish).
  zones,

  /// Boshqa (jadval, batareya, ilova, holat).
  other,
}

/// Filter'ga mos kelgan xabarlar (UI'da watch qilinadi).
final filteredNotificationsProvider =
    Provider.family<List<AppNotification>, NotificationFilter>(
        (ref, filter) {
  final list = ref.watch(notificationsProvider);
  return switch (filter) {
    NotificationFilter.all => list,
    NotificationFilter.sos => list
        .where((n) => n.type == NotificationType.sos)
        .toList(),
    NotificationFilter.zones => list
        .where((n) =>
            n.type == NotificationType.enterZone ||
            n.type == NotificationType.exitZone)
        .toList(),
    NotificationFilter.other => list
        .where((n) =>
            n.type != NotificationType.sos &&
            n.type != NotificationType.enterZone &&
            n.type != NotificationType.exitZone)
        .toList(),
  };
});
