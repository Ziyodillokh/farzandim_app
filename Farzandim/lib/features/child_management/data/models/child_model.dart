import 'package:farzandim/features/child_management/data/models/child_device_info.dart';
import 'package:farzandim/features/child_management/data/models/default_avatar.dart';
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
    this.blockUnknownSources = false,
    this.blockAllApps = false,
    this.blockUninstall = false,
    this.webFilterEnabled = false,
    this.blockedWebCategories = const [],
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
    // OS-ruxsat holatlari (Block 4 / M12) — top-level, deviceInfo'ga o'raladi.
    final locationPermission = json['locationPermission'] as bool?;
    final notificationPermission = json['notificationPermission'] as bool?;
    final backgroundAllowed = json['backgroundAllowed'] as bool?;
    final accessibilityEnabled = json['accessibilityEnabled'] as bool?;
    // Ekran vaqti manbasi — PACKAGE_USAGE_STATS ruxsati.
    final usagePermission = json['usagePermission'] as bool?;
    // Backend top-level fields'dan deviceInfo wrapper yaratamiz.
    final hasDeviceData =
        batteryLevel != null ||
        isCharging != null ||
        deviceModel != null ||
        androidVersion != null ||
        appVersion != null ||
        wifiName != null ||
        locationPermission != null ||
        notificationPermission != null ||
        backgroundAllowed != null ||
        accessibilityEnabled != null ||
        usagePermission != null;
    return Child(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      age: (json['age'] as int?) ?? 0,
      gender: _parseGender(json['gender'] as String?),
      region: (json['region'] as String?) ?? '',
      // Backend `photoPath` (MinIO key) — bu yerda faqat MAVJUDLIK bayrog'i
      // sifatida ishlatiladi. Ko'rsatish uchun proxy URL
      // `childAvatarUrlProvider` tomonidan quriladi
      // (`/children/:id/avatar/image`). Storage key'ni to'g'ridan-to'g'ri
      // network URL sifatida ishlatib bo'lmaydi.
      photoUrl: (json['photoPath'] as String?) ?? (json['photoUrl'] as String?),
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
              locationPermission: locationPermission,
              notificationPermission: notificationPermission,
              backgroundAllowed: backgroundAllowed,
              accessibilityEnabled: accessibilityEnabled,
              usagePermission: usagePermission,
            )
          : null,
      lastSeenAt: _parseIso8601(json['lastSeenAt']),
      createdAt: _parseIso8601(json['createdAt']) ?? DateTime.now(),
      blockUnknownSources: (json['blockUnknownSources'] as bool?) ?? false,
      blockAllApps: (json['blockAllApps'] as bool?) ?? false,
      blockUninstall: (json['blockUninstall'] as bool?) ?? false,
      webFilterEnabled: (json['webFilterEnabled'] as bool?) ?? false,
      blockedWebCategories:
          (json['blockedWebCategories'] as List?)?.cast<String>() ?? const [],
      // SOS "Qo'ng'iroq" uchun — backend endi phoneNumber qaytaradi
      // (ota-ona bola qo'shganda/tahrirlaganda kiritadi).
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  /// Bola identifikatori (Firebase Firestore document ID).
  final String id;

  /// Bola ismi.
  final String name;

  /// Bola yoshi (yil hisobida).
  final int age;

  /// Bola jinsi — default avatar shu maydon va `age` orqali tanlanadi
  /// (`defaultAvatarPath` getter'iga qarang).
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

  /// "Notanish manbalardan ilovalar" — Play Market'dan boshqa manbadan
  /// o'rnatilgan ilovalarni bloklash (Qurilma sozlamalari toggle'i). `true`
  /// bo'lsa bola qurilmasi sideload ilovalarni ishlatishni bloklaydi.
  final bool blockUnknownSources;

  /// "Barcha ilovalarni bloklash" — dashboard toggle'i. `true` bo'lsa bola
  /// qurilmasidagi barcha foydalanuvchi ilovalari bloklanadi (Child App
  /// device-policy'ni o'qib enforce qiladi).
  final bool blockAllApps;

  /// "O'chirishni taqiqlash" — `true` bo'lsa bola Farzandim ilovasini o'chira
  /// olmaydi (Child App device-policy'ni o'qib Android Device Admin'ni yoqadi,
  /// uninstall bloklanadi).
  final bool blockUninstall;

  /// "Xavfsiz internet filtri" — ota-ona ixtiyoriy yoqadigan tashqi web
  /// filtri (Qurilma sozlamalari). `true` bo'lsa bola qurilmasi tanlangan
  /// kategoriyalarni bloklaydi (Android'da enforce).
  final bool webFilterEnabled;

  /// Bloklangan web kategoriyalari: `ADULT` | `GAMBLING` | `SOCIAL`.
  /// Bo'sh ro'yxat = hech biri (webFilterEnabled true bo'lsa ham).
  final List<String> blockedWebCategories;

  /// Default avatar yo'li — bola o'z rasmini yuklamaguncha ko'rsatiladigan
  /// rasm.
  ///
  ///   O'G'IL  → yagona `boy.png` (yoshdan qat'i nazar)
  ///   QIZ     → yoshga qarab 3 tadan biri:
  ///               yosh < 10        → girl_6_10
  ///               10 <= yosh < 14  → girl_10_14
  ///               yosh >= 14       → girl_14
  ///
  /// Yosh kiritilmagan (0) yoki 10 dan kichik — eng yosh guruh (6-10).
  /// Rasmlar 1:1 (shaffof fon) — aylana avatar ichida to'liq.
  ///
  /// Mantiq `defaultAvatarAsset`da (DON reytingi ham shu funksiyani ishlatadi).
  String get defaultAvatarPath => defaultAvatarAsset(gender, age);

  /// Bola o'zining custom rasmiga egami (bytes yoki URL).
  ///
  /// `false` bo'lsa — `defaultAvatarPath` rasm ko'rsatiladi.
  bool get hasCustomPhoto => photoBytes != null || photoUrl != null;

  // ─── Jonli holat (heartbeat-aware) ──────────────────────────────────
  // Avval status har joyda har xil edi: dashboard/ro'yxat faqat `isConnected`
  // (pairing bayrog'i) ga qarardi → aloqa uzilsa ham "yashil" ko'rinardi.
  // Endi YAGONA mantiq: "online" = ulangan VA oxirgi heartbeat 3 daqiqa ichida.
  // Ostona backend ConnectionMonitor (CONNECTION_LOST_SECONDS≈120s) bilan
  // moslashtirilgan: dashboard "aloqa uzildi" holati va ota-onaga keladigan
  // "aloqa uzildi" push deyarli bir vaqtda chiqadi (avval 5 daq edi — UI hali
  // "online" ko'rsatib turganda push kelib nomuvofiqlik bo'lardi).

  /// Bola qurilmasi HOZIR jonli onlaynmi — `isConnected` (pairing) VA oxirgi
  /// heartbeat (`lastSeenAt`/`deviceInfo.lastSeen`) 2 daqiqa ichida bo'lishi
  /// shart. Heartbeat to'xtasa `false`. Ostona backend ConnectionMonitor
  /// (CONNECTION_LOST_SECONDS=120s) bilan AYNAN mos — avval 3 daqiqa edi va
  /// backend "aloqa uzildi" push yuborganda UI hali "online" ko'rsatib turardi.
  bool get isLiveOnline {
    final seen = lastSeenAt ?? deviceInfo?.lastSeen;
    return isConnected &&
        seen != null &&
        DateTime.now().difference(seen) < const Duration(minutes: 2);
  }

  /// Ulangan, lekin heartbeat 3 daqiqadan beri jim — "Aloqa uzildi" holati
  /// (oddiy "Ulanmagan"dan farqli; PDF M11). `false` bo'lsa: yo jonli onlayn,
  /// yo umuman ulanmagan.
  bool get isConnectionLost => isConnected && !isLiveOnline;

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
      if (phoneNumber != null && phoneNumber!.isNotEmpty)
        'phoneNumber': phoneNumber,
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
    bool? blockUnknownSources,
    bool? blockAllApps,
    bool? blockUninstall,
    bool? webFilterEnabled,
    List<String>? blockedWebCategories,
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
      blockUnknownSources: blockUnknownSources ?? this.blockUnknownSources,
      blockAllApps: blockAllApps ?? this.blockAllApps,
      blockUninstall: blockUninstall ?? this.blockUninstall,
      webFilterEnabled: webFilterEnabled ?? this.webFilterEnabled,
      blockedWebCategories: blockedWebCategories ?? this.blockedWebCategories,
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
        other.phoneNumber == phoneNumber &&
        other.blockUnknownSources == blockUnknownSources &&
        other.blockAllApps == blockAllApps &&
        other.blockUninstall == blockUninstall &&
        other.webFilterEnabled == webFilterEnabled &&
        listEquals(other.blockedWebCategories, blockedWebCategories);
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
    blockUnknownSources,
    blockAllApps,
    blockUninstall,
    webFilterEnabled,
    Object.hashAll(blockedWebCategories),
  );

  @override
  String toString() =>
      'Child(id: $id, name: $name, age: $age, gender: $gender, '
      'familyCode: $familyCode, hasPhoto: $hasCustomPhoto)';
}
