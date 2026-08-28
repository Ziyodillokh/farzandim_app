// ─────────────────────────────────────────────────────────────────────
// unlock_request_sync — bola "qo'shimcha vaqt" so'rovlarini serverdan
// olib kelish (FCM push uchun ZAXIRA kanal)
// ─────────────────────────────────────────────────────────────────────
//
// MUAMMO (2026-08-28'da jonli aniqlandi): bola so'rov yuborsa ota-onaga
// yetib bormasdi. Sabab — ota-ona ilovasida so'rovni ko'rsatadigan
// YAGONA kanal FCM push edi:
//   • `unlock_request:created` WS hodisasining tinglovchisi yo'q edi;
//   • backend yozadigan `Notification` yozuvi hech qachon o'qilmaydi
//     (bildirishnomalar ro'yxati faqat SharedPreferences'dan to'ladi).
// Push bitta sababga ko'ra yetib bormasa — bildirishnoma ruxsati o'chiq,
// FcmToken yozuvi yo'q, telefon Doze'da, ilova majburan to'xtatilgan —
// so'rov BUTUNLAY ko'rinmas bo'lardi va ota-ona uni ochib ko'radigan
// ro'yxat ham yo'q edi.
//
// Bu modul server haqiqatini so'raydi: ilova ochilganda va fondan
// qaytganda kutilayotgan (PENDING) so'rovlarni bildirishnomalar
// ro'yxatiga qo'shadi. Push bilan ikki nusxa chiqmasligi uchun dedup
// `unlockRequestId` bo'yicha — `NotificationsNotifier.addFromServer`.
//
// Xato bo'lsa jim qaytadi: mavjud push oqimi hech qachon buzilmaydi.

import 'dart:async';

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serverdagi kutilayotgan unlock so'rovlarini ro'yxatga qo'shuvchi servis.
final unlockRequestSyncProvider = Provider<UnlockRequestSync>((ref) {
  final service = UnlockRequestSync(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Kutilayotgan "qo'shimcha vaqt" so'rovlarini serverdan tortib oladi.
///
/// Hayot siklini O'ZI kuzatadi — sinxronizatsiya biror ekranning ochiq
/// turishiga bog'liq bo'lmasin (ota-ona push'ni o'tkazib yuborgan bo'lsa,
/// ilovani qayerdan ochishidan qat'i nazar so'rovni ko'rishi kerak).
class UnlockRequestSync with WidgetsBindingObserver {
  /// Riverpod `Ref` — repozitoriy va bildirishnomalar provayderi uchun.
  UnlockRequestSync(this._ref) {
    WidgetsBinding.instance.addObserver(this);

    // Backend `create()` da `emitToUser(parentId, 'unlock_request:created')`
    // yuboradi, lekin ota-ona ilovasida bu hodisaning TINGLOVCHISI yo'q
    // edi — faqat izohda eslatilgan. Ilova OCHIQ turganda so'rov shu
    // yerdan darhol keladi (lifecycle'ni kutmasdan). Payload backend
    // `serialize()` bilan bir xil shaklda, shuning uchun REST bilan
    // AYNAN bitta konvertor ishlatiladi.
    _wsSub = _ref
        .read(socketClientProvider)
        .eventStream('unlock_request:created')
        .listen(
          _onSocketEvent,
          onError: (Object e) => debugPrint('UnlockRequestSync ws: $e'),
        );
  }

  final Ref _ref;
  StreamSubscription<dynamic>? _wsSub;

  /// Kuzatuvchi va WS obunasini yopadi (provider dispose bo'lganda).
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_wsSub?.cancel());
    _wsSub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fondan qaytdi — push yetib bormagan bo'lsa ham so'rovni ko'rsatamiz.
    if (state == AppLifecycleState.resumed) {
      unawaited(sync());
    }
  }

  /// childId → ism. Backend `serialize()` bola ismini qaytarmaydi,
  /// shuning uchun mahalliy bolalar ro'yxatidan olamiz. Topilmasa
  /// sarlavha bo'sh qoladi — xabar matni baribir ko'rinadi.
  Map<String, String> _childNames() => <String, String>{
    for (final Child c
        in _ref.read(childrenProvider).valueOrNull ?? const <Child>[])
      c.id: c.name,
  };

  void _onSocketEvent(dynamic payload) {
    if (payload is! Map<String, dynamic>) return;
    final item = _toNotification(payload, _childNames());
    if (item == null) return;
    _ref.read(notificationsProvider.notifier).addFromServer([item]);
  }

  /// Serverdan PENDING so'rovlarni olib, bildirishnomalar ro'yxatiga
  /// qo'shadi. Startup'da va har `resumed` lifecycle'da chaqiriladi.
  Future<void> sync() async {
    try {
      final rows = await _ref
          .read(backendUnlockRequestRepositoryProvider)
          .listPending();
      if (rows.isEmpty) return;

      final names = _childNames();
      final items = rows
          .map((r) => _toNotification(r, names))
          .whereType<AppNotification>()
          .toList();
      if (items.isEmpty) return;

      _ref.read(notificationsProvider.notifier).addFromServer(items);
    } catch (e) {
      debugPrint('UnlockRequestSync.sync: $e');
    }
  }

  /// Backend `serialize()` javobini `AppNotification`ga aylantiradi.
  ///
  /// `data` kalitlari push payload'i bilan AYNAN bir xil bo'lishi shart —
  /// `notification_detail_screen` o'sha kalitlarni o'qiydi
  /// (`unlockRequestId`, `packageName`, `requestedMinutes`, `reason`).
  static AppNotification? _toNotification(
    Map<String, dynamic> row,
    Map<String, String> names,
  ) {
    final id = row['id'] as String?;
    if (id == null || id.isEmpty) return null;

    final childId = row['childId'] as String? ?? '';
    final kind = row['kind'] as String? ?? 'SCREEN_TIME';
    final packageName = row['packageName'] as String?;
    final reason = row['reason'] as String?;

    final rawMinutes = row['requestedMinutes'];
    final minutes = rawMinutes is num ? rawMinutes.toInt() : null;
    final minutesPart = minutes != null ? ' $minutes daqiqa' : '';

    // Matn backend push'idagi bilan bir xil ohangda. Farq: REST javobida
    // ilovaning ko'rinadigan nomi (appName) yo'q — paket nomi ishlatiladi.
    final body = kind == 'APP'
        ? '${packageName ?? "Bloklangan ilova"} uchun$minutesPart '
              "qo'shimcha vaqt so'rayapti."
        : "Qo'shimcha ekran vaqti$minutesPart so'rayapti.";

    final requestedAt =
        DateTime.tryParse(row['requestedAt'] as String? ?? '') ??
        DateTime.now();

    return AppNotification(
      // `id` = so'rov ID'si → qayta sync'da takrorlanmaydi.
      id: 'unlock-$id',
      type: NotificationType.unlockRequest,
      childId: childId,
      childName: names[childId] ?? '',
      title: names[childId] ?? '',
      message: body,
      timestamp: requestedAt,
      data: <String, dynamic>{
        'type': 'unlock_request',
        'unlockRequestId': id,
        'childId': childId,
        'kind': kind,
        if (packageName != null) 'packageName': packageName,
        if (minutes != null) 'requestedMinutes': minutes,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      },
    );
  }
}
