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

  /// Yangi (3-) qurilma akauntga kirmoqchi — 2-qurilma limiti. Ulangan
  /// qurilma tasdiqlaydi/rad etadi.
  sessionAccessRequest,

  /// Maktab davomati: keldi / kechikdi / chiqdi / kelmadi / erta ketdi
  /// (`school_attendance`, data: `kind`, `studentId`, `date`).
  schoolAttendance,

  /// Erta ketish so'rovi tasdiqlandi yoki rad etildi (`school_early_exit`).
  schoolEarlyExit,

  /// Maktabdan yangi e'lon (`SCHOOL_ANNOUNCEMENT`, `announcementId`).
  schoolAnnouncement,

  /// Maktab eslatmasi — yig'ilish va h.k. (`SCHOOL_REMINDER`); API yo'q,
  /// faqat xabar matni.
  schoolReminder,

  /// To'lov eslatmasi (`SCHOOL_PAYMENT_REMINDER`, `paymentReminderId`).
  schoolPayment,

  /// "To'laganman" so'roviga maktab javob berdi
  /// (`SCHOOL_VERIFICATION_ANSWERED`, `verificationId`).
  schoolVerification,

  /// Dars vaqtidagi telefon tartibi uchun qadam kerak
  /// (`SCHOOL_MODE_REMIND`, `studentId`).
  schoolMode,

  /// Growth haftalik hisoboti (`learning_weekly`, `childId`).
  learningReport,
}

/// `NotificationType` uchun UI helper'lar (ikona, rang, label).
extension NotificationTypeX on NotificationType {
  /// Ikona — kartochka chap tomonidagi yumaloq circle ichida.
  IconData get icon => switch (this) {
    NotificationType.sos => SolarIconsBold.dangerTriangle,
    NotificationType.enterZone => SolarIconsBold.login,
    NotificationType.exitZone => SolarIconsBold.logout,
    NotificationType.lowBattery => SolarIconsBold.batteryLow,
    NotificationType.appLimit => SolarIconsBold.stopwatchPause,
    NotificationType.scheduleStart => SolarIconsBold.calendar,
    NotificationType.scheduleReminder => SolarIconsBold.bellBing,
    NotificationType.offline => SolarIconsBold.cloudCross,
    NotificationType.online => SolarIconsBold.cloudCheck,
    NotificationType.pairRequest => SolarIconsBold.iPhone,
    NotificationType.game => SolarIconsBold.gamepad,
    NotificationType.unlockRequest => SolarIconsBold.lock,
    NotificationType.permissionChanged => SolarIconsBold.shield,
    NotificationType.sessionAccessRequest => SolarIconsBold.iPhone,
    NotificationType.schoolAttendance => SolarIconsBold.calendarMark,
    NotificationType.schoolEarlyExit => SolarIconsBold.walking,
    NotificationType.schoolAnnouncement => SolarIconsBold.letterUnread,
    NotificationType.schoolReminder => SolarIconsBold.bellBing,
    NotificationType.schoolPayment => SolarIconsBold.billList,
    NotificationType.schoolVerification => SolarIconsBold.billCheck,
    NotificationType.schoolMode => SolarIconsBold.squareAcademicCap,
    NotificationType.learningReport => SolarIconsBold.graphUp,
  };

  /// Tematik rang — circle fon (15% alpha) va ikona uchun ishlatamiz.
  Color get color => switch (this) {
    NotificationType.sos => const Color(0xFFEF4444), // qizil
    NotificationType.enterZone => const Color(0xFF4ADE80), // yashil
    NotificationType.exitZone => const Color(0xFFFB923C), // to'q sariq
    NotificationType.lowBattery => const Color(0xFFFBBF24), // sariq
    NotificationType.appLimit => const Color(0xFF7C6FE0), // binafsha
    NotificationType.scheduleStart => const Color(0xFF60A5FA), // moviy
    // brand forest green
    NotificationType.scheduleReminder => const Color(0xFF235347),
    NotificationType.offline => const Color(0xFF9CA3AF), // kulrang
    NotificationType.online => const Color(0xFF3DBFB4), // turkuaz
    NotificationType.pairRequest => const Color(0xFFFBBF24), // sariq — diqqat
    NotificationType.game => const Color(0xFF7C6FE0), // binafsha — o'yin
    // sariq — diqqat (qaror kerak)
    NotificationType.unlockRequest => const Color(0xFFFBBF24),
    // to'q sariq — ogohlantirish
    NotificationType.permissionChanged => const Color(0xFFFB923C),
    // ko'k — qurilma kirishi
    NotificationType.sessionAccessRequest => const Color(0xFF216BFF),
    // Maktab — brend ko'k oilasi; to'lov va o'sish — yashil/binafsha.
    NotificationType.schoolAttendance => const Color(0xFF60A5FA),
    NotificationType.schoolEarlyExit => const Color(0xFFFB923C),
    NotificationType.schoolAnnouncement => const Color(0xFF216BFF),
    NotificationType.schoolReminder => const Color(0xFF60A5FA),
    NotificationType.schoolPayment => const Color(0xFF4ADE80),
    NotificationType.schoolVerification => const Color(0xFF4ADE80),
    NotificationType.schoolMode => const Color(0xFFFBBF24),
    NotificationType.learningReport => const Color(0xFFA78BFA),
  };

  /// Qisqa label (badge yoki filter chip uchun, hozir UI'da ishlatmaymiz).
  String get label => switch (this) {
    NotificationType.sos => 'SOS',
    NotificationType.enterZone => 'Kirdi',
    NotificationType.exitZone => 'Chiqdi',
    NotificationType.lowBattery => 'Batareya',
    NotificationType.appLimit => 'Ilova limiti',
    NotificationType.scheduleStart => 'Jadval',
    NotificationType.scheduleReminder => 'Eslatma',
    NotificationType.offline => 'Offline',
    NotificationType.online => 'Online',
    NotificationType.pairRequest => "Pair so'rov",
    NotificationType.game => "O'yin",
    NotificationType.unlockRequest => "Ruxsat so'rovi",
    NotificationType.permissionChanged => "Ruxsat o'zgardi",
    NotificationType.sessionAccessRequest => "Kirish so'rovi",
    NotificationType.schoolAttendance => 'Davomat',
    NotificationType.schoolEarlyExit => 'Erta ketish',
    NotificationType.schoolAnnouncement => "E'lon",
    NotificationType.schoolReminder => 'Maktab eslatmasi',
    NotificationType.schoolPayment => "To'lov",
    NotificationType.schoolVerification => "To'lov javobi",
    NotificationType.schoolMode => 'Maktab tartibi',
    NotificationType.learningReport => "Bilim o'sishi",
  };

  /// Parvoz School yoki Growth xabarimi (maktab/o'sish ekranlariga olib
  /// boradi).
  bool get isSchool => switch (this) {
    NotificationType.schoolAttendance ||
    NotificationType.schoolEarlyExit ||
    NotificationType.schoolAnnouncement ||
    NotificationType.schoolReminder ||
    NotificationType.schoolPayment ||
    NotificationType.schoolVerification ||
    NotificationType.schoolMode ||
    NotificationType.learningReport => true,
    _ => false,
  };
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
    this.imageUrl,
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
    // Banner rasm — FCM `notification.imageUrl` (Android/iOS) yoki data'da
    // (`image`/`imageUrl`). Admin bildirishnomasi rasm bilan yuborsa keladi.
    final rawImage =
        message.notification?.android?.imageUrl ??
        message.notification?.apple?.imageUrl ??
        (data['image'] as String?) ??
        (data['imageUrl'] as String?);
    final image = (rawImage != null && rawImage.trim().isNotEmpty)
        ? rawImage.trim()
        : null;
    return AppNotification(
      id: message.messageId ?? 'fcm-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      childId: (data['childId'] as String?) ?? '',
      childName: (data['childName'] as String?) ?? '',
      title: message.notification?.title ?? (data['title'] as String?) ?? '',
      message: message.notification?.body ?? (data['message'] as String?) ?? '',
      timestamp: DateTime.now(),
      data: data,
      imageUrl: image,
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

  /// Ilova ichida ko'rsatiladigan banner rasm URL'i (admin bildirishnomani
  /// rasm bilan yuborsa). `null` = rasmsiz.
  final String? imageUrl;

  /// Ro'yxatda ko'rsatishga arziydigan xabarmi — sarlavha yoki matn bo'lishi
  /// shart. Bo'sh (dataOnly/silent sync) push'lar ro'yxatga tushmasin.
  bool get isDisplayable =>
      title.trim().isNotEmpty || message.trim().isNotEmpty;

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

  /// sessionAccessRequest uchun — `data['sessionRequestId']`.
  String? get sessionRequestId => data?['sessionRequestId'] as String?;

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

  /// Maktab push'lari: o'quvchi (`school_attendance`, `school_early_exit`,
  /// `SCHOOL_MODE_REMIND`).
  String? get studentId => _dataString('studentId');

  /// `SCHOOL_ANNOUNCEMENT` — e'lon id'si.
  String? get announcementId => _dataString('announcementId');

  /// `SCHOOL_PAYMENT_REMINDER` / `SCHOOL_VERIFICATION_ANSWERED`.
  String? get paymentReminderId => _dataString('paymentReminderId');

  /// `SCHOOL_VERIFICATION_ANSWERED` — javob berilgan so'rov.
  String? get verificationId => _dataString('verificationId');

  /// `school_attendance` — kun ("YYYY-MM-DD", Toshkent).
  String? get attendanceDate => _dataString('date');

  /// `data[key]` bo'sh bo'lmagan satr bo'lsa (bo'shliqlarsiz), aks holda null.
  String? _dataString(String key) {
    final value = data?[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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
      imageUrl: imageUrl,
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
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  /// Backend `data.type` → tur. Registr farq qilmaydi: davomat va Growth
  /// turlari kichik (`school_attendance`), e'lon/to'lov/School Mode esa
  /// KATTA harfda (`SCHOOL_ANNOUNCEMENT`) keladi.
  static NotificationType? _mapBackendType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
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
      case 'connection_restored':
        return NotificationType.online;
      case 'unlock_request':
        return NotificationType.unlockRequest;
      case 'session_access_request':
        return NotificationType.sessionAccessRequest;
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
      case 'school_attendance':
        return NotificationType.schoolAttendance;
      case 'school_early_exit':
        return NotificationType.schoolEarlyExit;
      case 'school_announcement':
        return NotificationType.schoolAnnouncement;
      case 'school_reminder':
        return NotificationType.schoolReminder;
      case 'school_payment_reminder':
        return NotificationType.schoolPayment;
      case 'school_verification_answered':
        return NotificationType.schoolVerification;
      case 'school_mode_remind':
        return NotificationType.schoolMode;
      case 'learning_weekly':
        return NotificationType.learningReport;
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
        imageUrl: json['imageUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
