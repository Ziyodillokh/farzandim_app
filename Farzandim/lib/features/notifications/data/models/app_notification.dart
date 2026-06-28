import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bildirishnoma turi — ikona, rang va yorliqni aniqlaydi.
enum NotificationType {
  /// Bola SOS tugmasini bosgan — eng yuqori muhimlikdagi qizil xabar.
  sos,

  /// Geo-zonaga kirgan.
  enterZone,

  /// Geo-zonadan chiqqan.
  exitZone,

  /// Batareya pastligi haqida ogohlantirish.
  lowBattery,

  /// Belgilangan ilova vaqt limiti tugadi.
  appLimit,

  /// Jadval bo'yicha bir voqea boshlandi.
  scheduleStart,

  /// Jadval boshlanishidan oldin reminder push (Cloud Function
  /// `scheduleReminder` har daqiqada `reminderMinutes` oldin
  /// yuboradi).
  scheduleReminder,

  /// Bola qurilmasi internet aloqasini yo'qotdi.
  offline,

  /// Bola qurilmasi internet aloqasiga qaytdi.
  online,

  /// Bola yangi qurilmadan ulanmoqchi — parent tasdiqi kerak
  /// (Backend 0.6.0 — Sprint 4.4.25).
  pairRequest,

  /// Bola o'yin (CATEGORY_GAME) ochdi — pastda "Bloklash" tugmasi bilan.
  game,

  /// Bola bloklangan ilova/ekran-vaqt uchun qo'shimcha vaqt so'rayapti —
  /// "Vaqt ber" (5–60 daq) / "Rad et" tugmalari bilan.
  unlockRequest,

  /// Bola telefonida muhim ruxsat (joylashuv/bildirishnoma/fon/maxsus
  /// imkoniyatlar) o'chirildi — holat ogohlantirishi.
  permissionChanged,
}

/// `NotificationType` uchun UI helper'lar (ikona, rang, label).
extension NotificationTypeX on NotificationType {
  /// Ikona — kartochka chap tomonidagi yumaloq circle ichida.
  IconData get icon {
    switch (this) {
      case NotificationType.sos:
        return SolarIconsBold.dangerTriangle;
      case NotificationType.enterZone:
        return SolarIconsBold.login;
      case NotificationType.exitZone:
        return SolarIconsBold.logout;
      case NotificationType.lowBattery:
        return SolarIconsBold.batteryLow;
      case NotificationType.appLimit:
        return SolarIconsBold.stopwatchPause;
      case NotificationType.scheduleStart:
        return SolarIconsBold.calendar;
      case NotificationType.scheduleReminder:
        return SolarIconsBold.bellBing;
      case NotificationType.offline:
        return SolarIconsBold.cloudCross;
      case NotificationType.online:
        return SolarIconsBold.cloudCheck;
      case NotificationType.pairRequest:
        return SolarIconsBold.iPhone;
      case NotificationType.game:
        return SolarIconsBold.gamepad;
      case NotificationType.unlockRequest:
        return SolarIconsBold.lock;
      case NotificationType.permissionChanged:
        return SolarIconsBold.shield;
    }
  }

  /// Tematik rang — circle fon (15% alpha) va ikona uchun ishlatamiz.
  Color get color {
    switch (this) {
      case NotificationType.sos:
        return const Color(0xFFEF4444); // qizil
      case NotificationType.enterZone:
        return const Color(0xFF4ADE80); // yashil
      case NotificationType.exitZone:
        return const Color(0xFFFB923C); // to'q sariq
      case NotificationType.lowBattery:
        return const Color(0xFFFBBF24); // sariq
      case NotificationType.appLimit:
        return const Color(0xFF7C6FE0); // binafsha
      case NotificationType.scheduleStart:
        return const Color(0xFF60A5FA); // moviy
      case NotificationType.scheduleReminder:
        return const Color(0xFF235347); // brand forest green
      case NotificationType.offline:
        return const Color(0xFF9CA3AF); // kulrang
      case NotificationType.online:
        return const Color(0xFF3DBFB4); // turkuaz
      case NotificationType.pairRequest:
        return const Color(0xFFFBBF24); // sariq — diqqat
      case NotificationType.game:
        return const Color(0xFF7C6FE0); // binafsha — o'yin
      case NotificationType.unlockRequest:
        return const Color(0xFFFBBF24); // sariq — diqqat (qaror kerak)
      case NotificationType.permissionChanged:
        return const Color(0xFFFB923C); // to'q sariq — ogohlantirish
    }
  }

  /// Qisqa label (badge yoki filter chip uchun, hozir UI'da ishlatmaymiz).
  String get label {
    switch (this) {
      case NotificationType.sos:
        return 'SOS';
      case NotificationType.enterZone:
        return 'Kirdi';
      case NotificationType.exitZone:
        return 'Chiqdi';
      case NotificationType.lowBattery:
        return 'Batareya';
      case NotificationType.appLimit:
        return 'Ilova limiti';
      case NotificationType.scheduleStart:
        return 'Jadval';
      case NotificationType.scheduleReminder:
        return 'Eslatma';
      case NotificationType.offline:
        return 'Offline';
      case NotificationType.online:
        return 'Online';
      case NotificationType.pairRequest:
        return "Pair so'rov";
      case NotificationType.game:
        return "O'yin";
      case NotificationType.unlockRequest:
        return "Ruxsat so'rovi";
      case NotificationType.permissionChanged:
        return "Ruxsat o'zgardi";
    }
  }
}

/// Bitta bildirishnoma — push xabar yoki app ichidagi event.
///
/// Cloud Function bola Child App'dan kelgan event'larga (SOS, geo-zona
/// kirish/chiqish, va h.k.) javoban FCM orqali yuboradi. Parent App
/// `firebase_messaging` orqali oladi.
@immutable
class AppNotification {
  /// `AppNotification` konstruktor.
  const AppNotification({
    required this.id,
    required this.type,
    required this.childId,
    required this.childName,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  /// FCM `RemoteMessage`'dan yaratish.
  ///
  /// **FCM payload formati** (Cloud Function yuboruvchi):
  /// ```json
  /// {
  ///   "notification": { "title": "SOS!", "body": "..." },
  ///   "data": {
  ///     "type": "sos",
  ///     "childId": "abc",
  ///     "childName": "Sevinch"
  ///   }
  /// }
  /// ```
  ///
  /// Bilinmagan `type` kelsa `online` (eng zararsiz) ishlatamiz —
  /// xabar baribir ko'rinadi, lekin maxsus navigatsiya ishlamaydi.
  factory AppNotification.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final rawType = data['type'] as String?;
    // Backend snake_case yuboradi (`pair_request`), Dart enum
    // camelCase (`pairRequest`) — qo'lda map qilamiz.
    final type =
        _mapBackendType(rawType) ??
        NotificationType.values.firstWhere(
          (t) => t.name == rawType,
          orElse: () => NotificationType.online,
        );
    return AppNotification(
      id: message.messageId ?? 'fcm-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      childId: (data['childId'] as String?) ?? '',
      childName: (data['childName'] as String?) ?? '',
      title: message.notification?.title ?? (data['title'] as String?) ?? '',
      message: message.notification?.body ?? (data['message'] as String?) ?? '',
      timestamp: DateTime.now(),
      data: data,
    );
  }

  /// Xabar identifikatori (Bosqich 6.B'da Firestore document ID).
  final String id;

  /// Turi — ikona/rang/handle navigatsiyasini aniqlaydi.
  final NotificationType type;

  /// Qaysi bola haqida xabar.
  final String childId;

  /// Bola ismi — xabar matnida o'zbekcha tilda yoritish uchun.
  final String childName;

  /// Sarlavha — birinchi qatorga chiqadi.
  final String title;

  /// Tafsilot matni — sarlavha ostida 2 qatorgacha.
  final String message;

  /// Qachon yuborilgan.
  final DateTime timestamp;

  /// Foydalanuvchi xabarni o'qiganmi (kartocha bossa true bo'ladi).
  final bool isRead;

  /// Qo'shimcha kontekst (geo-zona ID, ilova nomi, va h.k.) —
  /// kelajakda Firestore mapping uchun ishlatamiz, hozircha
  /// to'ldirilmaydi.
  final Map<String, dynamic>? data;

  /// Parent qaror qabul qilishi kerak bo'lgan xabarmi — kartochkada
  /// "Tekshirish" / "Rad etish" tugmalari ko'rsatiladi. Hozircha faqat
  /// `pairRequest` (yangi qurilma ulanmoqchi).
  bool get isActionable =>
      type == NotificationType.pairRequest ||
      type == NotificationType.unlockRequest;

  /// pairRequest uchun — `data['pairRequestId']` (rad etish API'siga kerak).
  String? get pairRequestId => data?['pairRequestId'] as String?;

  /// unlockRequest uchun — `data['unlockRequestId']` (decide API'siga kerak).
  String? get unlockRequestId => data?['unlockRequestId'] as String?;

  /// unlockRequest turi — 'APP' yoki 'SCREEN_TIME'.
  String? get unlockKind => data?['kind'] as String?;

  /// unlockRequest uchun — bola so'ragan daqiqa (5..60). FCM string yuboradi,
  /// WS esa int — ikkisini ham qo'llab-quvvatlaymiz.
  int? get requestedMinutes {
    final v = data?['requestedMinutes'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// unlockRequest uchun — bola yozgan sabab (ixtiyoriy, bo'sh bo'lishi
  /// mumkin).
  String? get unlockReason {
    final v = data?['reason'];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  /// Bu xabar bola unlock so'rovimi.
  bool get isUnlockRequest => type == NotificationType.unlockRequest;

  /// O'yin xabari — pastda "Bloklash" tugmasi ko'rsatiladi.
  bool get isGame => type == NotificationType.game;

  /// O'yin (yoki ilova) paket nomi — "Bloklash" uchun (`app-limits`).
  String? get packageName => data?['packageName'] as String?;

  /// O'yin/ilova nomi (push data'sidan) — Bloklash xabarida ko'rsatish uchun.
  String? get appName => data?['appName'] as String?;

  /// Yangi `AppNotification` — `markAsRead` uchun ishlatamiz.
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      childId: childId,
      childName: childName,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      data: data,
    );
  }

  /// SharedPreferences persistence — JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'childId': childId,
    'childName': childName,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    if (data != null) 'data': data,
  };

  static NotificationType? _mapBackendType(String? raw) {
    switch (raw) {
      case 'pair_request':
        return NotificationType.pairRequest;
      case 'sos':
        return NotificationType.sos;
      case 'geofence_enter':
      case 'enter_zone':
        return NotificationType.enterZone;
      case 'geofence_exit':
      case 'exit_zone':
        return NotificationType.exitZone;
      case 'low_battery':
        return NotificationType.lowBattery;
      case 'connection_lost':
        return NotificationType.offline;
      case 'unlock_request':
        return NotificationType.unlockRequest;
      case 'permission_changed':
        return NotificationType.permissionChanged;
      case 'app_limit':
        return NotificationType.appLimit;
      case 'schedule_start':
        return NotificationType.scheduleStart;
      case 'schedule_reminder':
        return NotificationType.scheduleReminder;
      case 'game':
        return NotificationType.game;
      default:
        return null;
    }
  }

  /// SharedPreferences persistence — JSON dan tiklash.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    try {
      final typeName = json['type'] as String?;
      final type = NotificationType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => NotificationType.online,
      );
      final ts = DateTime.tryParse(json['timestamp'] as String? ?? '');
      if (ts == null) return null;
      return AppNotification(
        id: json['id'] as String? ?? '',
        type: type,
        childId: json['childId'] as String? ?? '',
        childName: json['childName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        timestamp: ts,
        isRead: json['isRead'] as bool? ?? false,
        data: (json['data'] as Map?)?.cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }
}
