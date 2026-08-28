// Bildirishnomalar ro'yxati: SharedPreferences'da saqlanadi, restart'da
// tiklanadi, eng yangi 100 tasi qoladi.

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
/// Foreground push `addFromFcm` orqali keladi; fonda kelganlari bg isolate
/// "pending" navbatiga yoziladi va startup hamda har resume'da
/// `syncPending()` qo'shib oladi. Har o'zgarish SharedPreferences'ga
/// saqlanadi.
class NotificationsNotifier extends StateNotifier<List<AppNotification>>
    with WidgetsBindingObserver {
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
            // Bo'sh (sarlavhasiz+matnsiz) eski yozuvlar ro'yxatdan tushsin.
            .where((n) => n.isDisplayable)
            .toList();
        if (list.isNotEmpty) {
          // To'g'ridan almashtirmaymiz: _load tugaguncha addFromFcm kelgan
          // bo'lishi mumkin va `state = list` o'sha yangi xabarni o'chirib
          // yuborardi. Shu uchun id bo'yicha merge — yangilar tepada.
          final liveIds = state.map((n) => n.id).toSet();
          state = [...state, ...list.where((n) => !liveIds.contains(n.id))];
        }
      }
    } catch (e) {
      debugPrint('NotificationsNotifier._load: $e');
    }
    await syncPending();
  }

  /// Fonda (bg isolate) kelgan push'larni pending navbatdan ro'yxatga
  /// ko'chirish.
  ///
  /// Bg handler har xabarni o'z noyob kalitiga yozadi; bu yerda faqat
  /// o'zimiz o'qigan kalitlarni o'chiramiz — shu orada bg isolate qo'shgan
  /// yangi kalit yo'qolmaydi (massiv ustida read-modify-write poygasi yo'q).
  /// Dedup `id` bo'yicha — tap orqali qo'shilgan xabar takrorlanmaydi.
  Future<void> syncPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bg isolate yozganini ko'rish uchun reload shart.
      await prefs.reload();

      const prefix = '$kPendingNotificationsPrefsKey:';
      final pendingKeys = prefs
          .getKeys()
          .where((k) => k.startsWith(prefix))
          .toList();

      // Eski build umumiy massiv kalitiga yozgan bo'lishi mumkin — bir
      // martalik drenaj, yangilanishdan keyin xabarlar yo'qolib qolmasin.
      final legacyRaw = prefs.getString(kPendingNotificationsPrefsKey);

      if (pendingKeys.isEmpty && (legacyRaw == null || legacyRaw.isEmpty)) {
        return;
      }

      final parsed = <AppNotification>[];
      for (final k in pendingKeys) {
        final raw = prefs.getString(k);
        if (raw != null && raw.isNotEmpty) {
          try {
            final n = AppNotification.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            if (n != null) parsed.add(n);
          } catch (_) {
            // buzuq yozuv — tashlab yuboramiz
          }
        }
        // Faqat o'zimiz o'qigan kalitni o'chiramiz (concurrent append xavfsiz).
        await prefs.remove(k);
      }

      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        try {
          parsed.addAll(
            (jsonDecode(legacyRaw) as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .whereType<AppNotification>(),
          );
        } catch (_) {
          // buzuq legacy — tashlab yuboramiz
        }
        await prefs.remove(kPendingNotificationsPrefsKey);
      }

      if (parsed.isEmpty) return;

      // Vaqt bo'yicha eski→yangi — yangilari ro'yxat tepasiga chiqsin.
      parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Dedup: state'dagi va pending ichidagi takror id'lar (FCM redelivery).
      final seen = state.map((n) => n.id).toSet();
      final fresh = <AppNotification>[];
      for (final n in parsed) {
        // Bo'sh (dataOnly/silent) push'lar ro'yxatga qo'shilmaydi.
        if (!n.isDisplayable) continue;
        if (seen.add(n.id)) fresh.add(n);
      }
      if (fresh.isEmpty) return;

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

  /// Serverdan olib kelingan xabarlarni ro'yxatga qo'shadi (push zaxirasi).
  ///
  /// Dedup IKKI bosqichli va ikkinchisi SHART: push orqali kelgan
  /// nusxaning `id`si FCM `messageId` bo'ladi, serverdan kelganiniki esa
  /// `unlock-<so'rov id>`. Faqat `id` bo'yicha solishtirsak bitta so'rov
  /// ro'yxatda ikki marta ko'rinardi. Shuning uchun `data`dagi
  /// `unlockRequestId` ham taqqoslanadi.
  void addFromServer(List<AppNotification> items) {
    if (items.isEmpty) return;

    final ids = state.map((n) => n.id).toSet();
    final requestIds = state
        .map((n) => n.data?['unlockRequestId'])
        .whereType<String>()
        .toSet();

    final fresh = <AppNotification>[];
    for (final n in items) {
      if (!n.isDisplayable) continue;
      if (!ids.add(n.id)) continue;
      final rid = n.data?['unlockRequestId'];
      if (rid is String && !requestIds.add(rid)) continue;
      fresh.add(n);
    }
    if (fresh.isEmpty) return;

    // Server yangi→eski tartibda qaytaradi — shu tartibda tepaga qo'yamiz.
    state = [...fresh, ...state];
    if (state.length > _maxStored) {
      state = state.sublist(0, _maxStored);
    }
    unawaited(_persist());
  }

  /// FCM dan kelgan xabarni ro'yxatga qo'shadi.
  void addFromFcm(AppNotification notification) {
    // Bo'sh (sarlavhasiz+matnsiz) silent push'lar ro'yxatga tushmasin.
    if (!notification.isDisplayable) return;
    if (state.any((n) => n.id == notification.id)) return;
    // Unlock so'rovi allaqachon serverdan (sync yoki WS) kelgan bo'lishi
    // mumkin — u holda `id` boshqacha (`unlock-<id>`) va yuqoridagi
    // tekshiruv uni ko'rmaydi. `unlockRequestId` — ikki nusxani
    // bog'laydigan yagona maydon.
    final rid = notification.data?['unlockRequestId'];
    if (rid is String &&
        state.any((n) => n.data?['unlockRequestId'] == rid)) {
      return;
    }
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
    Provider.family<List<AppNotification>, NotificationFilter>((ref, filter) {
      final list = ref.watch(notificationsProvider);
      return switch (filter) {
        NotificationFilter.all => list,
        NotificationFilter.sos =>
          list.where((n) => n.type == NotificationType.sos).toList(),
        NotificationFilter.zones =>
          list
              .where(
                (n) =>
                    n.type == NotificationType.enterZone ||
                    n.type == NotificationType.exitZone,
              )
              .toList(),
        NotificationFilter.other =>
          list
              .where(
                (n) =>
                    n.type != NotificationType.sos &&
                    n.type != NotificationType.enterZone &&
                    n.type != NotificationType.exitZone,
              )
              .toList(),
      };
    });
