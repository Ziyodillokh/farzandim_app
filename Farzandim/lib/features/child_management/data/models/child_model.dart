import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter/foundation.dart';

/// Bola ma'lumotlari modeli.
///
/// **Immutable** — bir marta yaratilgach o'zgarmaydi. Mutate qilish o'rniga
/// `copyWith()` orqali yangi nusxasi yaratiladi (Riverpod state management
/// uchun zarur — state har o'zgarganda yangi obyekt bo'lishi shart).
///
/// Hozircha `freezed` ishlatmaymiz — yangi boshlovchi uchun qo'lda yozilgan
/// kod aniqroq. Keyinroq, modellar soni o'sganda freezed'ga o'tamiz.
@immutable
class Child {
  /// `Child` konstruktor.
  const Child({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.region,
    required this.familyCode,
    required this.createdAt,
    this.photoUrl,
    this.photoBytes,
    this.deviceModel,
    this.isConnected = false,
    this.linkedDeviceUid,
    this.pairedAt,
    this.deviceInfo,
    this.lastSeenAt,
    this.phoneNumber,
  });

  /// Backend REST JSON'dan `Child` yaratish (Sprint 4.4 Bosqich 3).
  ///
  /// Backend kontrakt (Child obyekti):
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "parentId": "uuid",
  ///   "childUserId": "uuid" | null,    // → linkedDeviceUid
  ///   "name": "Umar",
  ///   "age": 10 | null,
  ///   "gender": "male" | "female" | null,
  ///   "region": "Toshkent" | null,      // optional, deploy bo'lganda
  ///   "photoUrl": "https://..." | null, // optional, deploy bo'lganda
  ///   "familyCode": "29416",
  ///   "pairedAt": "ISO 8601" | null,
  ///   "isConnected": false,
  ///   "lastSeenAt": "ISO 8601" | null,
  ///   "batteryLevel": 75 | null,        // → deviceInfo.batteryLevel
  ///   "isCharging": false | null,       // → deviceInfo.isCharging
  ///   "deviceModel": "Redmi" | null,    // top-level + deviceInfo.model
  ///   "createdAt": "ISO 8601",
  ///   "updatedAt": "ISO 8601"
  /// }
  /// ```
  ///
  /// Mapping:
  /// - `childUserId` → `linkedDeviceUid` (semantik bir xil, nom farqi)
  /// - `batteryLevel/isCharging/deviceModel` → `deviceInfo` wrapping
  /// - `gender` ("male"/"female") → `Gender.male/female` enum
  /// - `age` null bo'lsa default 0 (UI'da "yosh kiritilmagan" sifatida)
  factory Child.fromJson(Map<String, dynamic> json) {
    final batteryLevel = json['batteryLevel'] as int?;
    final isCharging = json['isCharging'] as bool?;
    final deviceModel = json['deviceModel'] as String?;
    final androidVersion = json['androidVersion'] as String?;
    final appVersion = json['appVersion'] as String?;
    final wifiName = json['wifiName'] as String?;
    // Backend top-level fields'dan deviceInfo wrapper yaratamiz.
    final hasDeviceData = batteryLevel != null ||
        isCharging != null ||
        deviceModel != null ||
        androidVersion != null ||
        appVersion != null ||
        wifiName != null;
    return Child(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      age: (json['age'] as int?) ?? 0,
      gender: _parseGender(json['gender'] as String?),
      region: (json['region'] as String?) ?? '',
      deviceModel: deviceModel,
      familyCode: (json['familyCode'] as String?) ?? '',
      isConnected: (json['isConnected'] as bool?) ?? false,
      linkedDeviceUid: json['childUserId'] as String?,
      pairedAt: _parseIso8601(json['pairedAt']),
      deviceInfo: hasDeviceData
          ? ChildDeviceInfo(
              deviceModel: deviceModel,
              androidVersion: androidVersion,
              appVersion: appVersion,
              wifiName: wifiName,
              batteryLevel: batteryLevel,
              isCharging: isCharging,
              isOnline: json['isConnected'] as bool? ?? false,
              lastSeen: _parseIso8601(json['lastSeenAt']),
            )
          : null,
      lastSeenAt: _parseIso8601(json['lastSeenAt']),
      createdAt: _parseIso8601(json['createdAt']) ?? DateTime.now(),
      // phoneNumber Backend'da yo'q (Sprint 4.4 skip — kelajakda Child App
      // SIM'dan o'qib alohida endpoint orqali yuboradi)
    );
  }

  /// Bola identifikatori (Firebase Firestore document ID).
  final String id;

  /// Bola ismi.
  final String name;

  /// Bola yoshi (yil hisobida).
  final int age;

  /// Bola jinsi — default avatar sticker'i shu maydon va `age` orqali
  /// tanlanadi (`defaultStickerPath` getter'iga qarang).
  final Gender gender;

  /// Hudud (Toshkent, Samarqand, va h.k.).
  final String region;

  /// Profil rasmi URL'i (Firebase Storage'da). Yo'q bo'lsa `null`.
  ///
  /// **Hozir har doim `null`** — Bosqich 1.6'da Firebase Storage qo'shilganda
  /// `photoBytes` URL'ga konvertatsiya qilinib shu yerda saqlanadi.
  final String? photoUrl;

  /// Tanlangan rasm bayt massivi — **transient** (faqat hozirgi sessiya).
  ///
  /// Foydalanuvchi formada rasm tanlaganda bu yerga yoziladi. Ilova
  /// yopilsa yo'qoladi (Firestore'ga yozilmaydi). Bosqich 1.6'da
  /// Firebase Storage'ga yuklanib, `photoUrl`'ga konvertatsiya bo'ladi.
  ///
  /// Bytes formati universal — Web/iOS/Android'da bir xil ishlaydi.
  final Uint8List? photoBytes;

  /// Bola qurilmasining modeli (masalan, "Redmi Note 12"). Child App
  /// ulanganda avtomatik aniqlanadi. Ulanmagan bo'lsa `null`.
  final String? deviceModel;

  /// Profil yaratilgan vaqt.
  final DateTime createdAt;

  /// 5 raqamli oila kodi — Child App orqali qurilmani bog'lash uchun.
  /// Har bola alohida unique kod oladi (collision detection bilan
  /// `ChildrenNotifier.generateFamilyCode()`'da generatsiya qilinadi).
  final String familyCode;

  /// Bola qurilmasi (Child App) ulanganmi va aktiv ma'lumot yuboryaptimi.
  ///
  /// `true` — Child App muvaffaqiyatli pairing qilgan va Firestore'ga
  /// yozilgan. Bola ilovani o'chirsa ham `true` qoladi (real online status
  /// emas, "qurilma ulangan" deb tushuniladi).
  final bool isConnected;

  /// Pairing qilgan bola qurilmasining Anonymous Firebase Auth UID.
  /// Child App `verifyCode()` davomida shu yerga yozadi.
  /// `null` — hali pair qilinmagan.
  final String? linkedDeviceUid;

  /// Pairing tugagan vaqt (Child App `verifyCode()` davomida yoziladi).
  final DateTime? pairedAt;

  /// Child App tomonidan yozilgan real-time qurilma ma'lumoti
  /// (model, OS, batareya, Wi-Fi, online holat). `null` — hali
  /// Child App heartbeat yubormagan.
  final ChildDeviceInfo? deviceInfo;

  /// Bola qurilmasidan kelgan eng so'nggi heartbeat vaqti
  /// (`children/{id}.lastSeenAt`). `deviceInfo.lastSeen` bilan ko'pincha
  /// teng, lekin alohida saqlanadi — query'lar uchun to'g'ridan-to'g'ri
  /// indekslab bo'ladi.
  final DateTime? lastSeenAt;

  /// Bola telefon raqami — SOS dialog'da "Qo'ng'iroq" tugmasi shu
  /// raqamga `tel:` URI ochadi. Child App pair tugagandan keyin SIM
  /// kartadan avtomatik o'qib yozadi (`TelephonyManager.line1Number`).
  ///
  /// `null` bo'lishi mumkin — SIM raqami yozilmagan yoki permission
  /// rad etilgan holatda. Bu holatda Parent App "telefon kiritilmagan"
  /// SnackBar ko'rsatadi.
  final String? phoneNumber;

  /// Default avatar sticker yo'li — `assets/stickers/`'dan, jinsi va
  /// yosh guruhiga qarab.
  ///
  /// 6 ta sticker mavjud: `{boy|girl}_{5_9|10_14|15_18}.svg`.
  /// Yosh chegarada bo'lsa pastki guruhga tushadi (yoshi 9 → "5_9",
  /// yoshi 10 → "10_14"). Mahsulot 6-18 yoshga mo'ljallangan, lekin
  /// chegaradan tashqari yoshlar (4 yoki 19+) eng yaqin guruhga tushadi.
  String get defaultStickerPath {
    final genderPrefix = gender == Gender.male ? 'boy' : 'girl';
    final String ageRange;
    if (age <= 9) {
      ageRange = '5_9';
    } else if (age <= 14) {
      ageRange = '10_14';
    } else {
      ageRange = '15_18';
    }
    return 'assets/stickers/${genderPrefix}_$ageRange.svg';
  }

  /// Bola o'zining custom rasmiga egami (bytes yoki URL).
  ///
  /// `false` bo'lsa — `defaultStickerPath` SVG sticker ko'rsatiladi.
  bool get hasCustomPhoto => photoBytes != null || photoUrl != null;

  /// Backend REST POST/PUT uchun JSON (Sprint 4.4).
  ///
  /// Server tomon o'zi boshqaradigan fieldlarni (`id`, `parentId`,
  /// `familyCode`, `createdAt`, `updatedAt`, `pairedAt`, `isConnected`,
  /// `lastSeenAt`, `childUserId`) yubormaymiz. Faqat parent o'zgartirishi
  /// mumkin bo'lgan fieldlar (`name`, `age`, `gender`, `region`).
  /// `photoUrl` alohida `/avatar` endpoint orqali yangilanadi.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (age > 0) 'age': age,
      'gender': gender == Gender.male ? 'male' : 'female',
      if (region.isNotEmpty) 'region': region,
    };
  }

  // ─── Backend JSON parser helpers (fromJson factory uchun) ────────────
  static Gender _parseGender(String? raw) {
    switch (raw) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      default:
        return Gender.male;
    }
  }

  static DateTime? _parseIso8601(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  /// Yangi bola yaratish — bitta yoki bir nechta maydonni o'zgartiradi.
  ///
  /// Eslatma: `null` qiymat berish (masalan, `photoUrl: null`) yordam
  /// bermaydi — kod uni "o'zgartirmaslik" deb tushunadi. Maydon'ni o'chirish
  /// kerak bo'lsa, to'g'ridan-to'g'ri konstruktor bilan yangi `Child`
  /// yarating.
  Child copyWith({
    String? id,
    String? name,
    int? age,
    Gender? gender,
    String? region,
    String? photoUrl,
    Uint8List? photoBytes,
    String? deviceModel,
    DateTime? createdAt,
    String? familyCode,
    bool? isConnected,
    String? linkedDeviceUid,
    DateTime? pairedAt,
    ChildDeviceInfo? deviceInfo,
    DateTime? lastSeenAt,
    String? phoneNumber,
  }) {
    return Child(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      region: region ?? this.region,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBytes: photoBytes ?? this.photoBytes,
      deviceModel: deviceModel ?? this.deviceModel,
      createdAt: createdAt ?? this.createdAt,
      familyCode: familyCode ?? this.familyCode,
      isConnected: isConnected ?? this.isConnected,
      linkedDeviceUid: linkedDeviceUid ?? this.linkedDeviceUid,
      pairedAt: pairedAt ?? this.pairedAt,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  /// `photoBytes` `==` va `hashCode`'dan tashqarida qoldirilgan —
  /// bayt taqqoslash qimmat (50KB rasm = 50K element solishtirish) va
  /// bizning use case'da kerak emas (state o'zgarishi list reference
  /// orqali aniqlanadi, `id` esa hash uchun yetarli unique).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Child &&
        other.id == id &&
        other.name == name &&
        other.age == age &&
        other.gender == gender &&
        other.region == region &&
        other.photoUrl == photoUrl &&
        other.deviceModel == deviceModel &&
        other.createdAt == createdAt &&
        other.familyCode == familyCode &&
        other.isConnected == isConnected &&
        other.linkedDeviceUid == linkedDeviceUid &&
        other.pairedAt == pairedAt &&
        other.deviceInfo == deviceInfo &&
        other.lastSeenAt == lastSeenAt &&
        other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        age,
        gender,
        region,
        photoUrl,
        deviceModel,
        createdAt,
        familyCode,
        isConnected,
        linkedDeviceUid,
        pairedAt,
        deviceInfo,
        lastSeenAt,
        phoneNumber,
      );

  @override
  String toString() =>
      'Child(id: $id, name: $name, age: $age, gender: $gender, '
      'familyCode: $familyCode, hasPhoto: $hasCustomPhoto)';
}
