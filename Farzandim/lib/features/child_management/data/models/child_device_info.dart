import 'package:flutter/foundation.dart';

/// Bola qurilmasi haqida real-time ma'lumot — Child App tomonidan
/// Firestore'ga yoziladi (`children/{childId}.deviceInfo` map).
///
/// **Bosqich 8.B**: mock o'chirildi — barcha maydonlar Child App
/// tarafidan to'ldiriladi. Maydon `null` bo'lsa Child App hali
/// yubormagan yoki ruxsat yo'q (masalan, `wifiName` Location ruxsat
/// bermagan bolada `null` qoladi).
@immutable
class ChildDeviceInfo {
  /// `ChildDeviceInfo` konstruktor.
  const ChildDeviceInfo({
    this.deviceModel,
    this.androidVersion,
    this.appVersion,
    this.batteryLevel,
    this.isCharging,
    this.wifiName,
    this.isOnline = false,
    this.lastSeen,
  });

  /// Qurilma modeli (`samsung SM-N950F`, `Redmi Note 12`, va h.k.).
  final String? deviceModel;

  /// OS versiyasi (`Android 9`, `iOS 17`, va h.k.).
  final String? androidVersion;

  /// Bola qurilmasidagi Farzandim Child App versiyasi.
  final String? appVersion;

  /// Batareya foizi (0-100). `null` — hali Child App yubormagan.
  final int? batteryLevel;

  /// Hozir zaryadlanyaptimi. `null` — noma'lum.
  final bool? isCharging;

  /// Wi-Fi tarmog'i nomi. `null` — Location ruxsat yo'q yoki ulanmagan.
  final String? wifiName;

  /// Qurilma hozir online'mi (Child App ochiq + heartbeat yangilangan).
  final bool isOnline;

  /// So'nggi heartbeat vaqti (Child App'dan Firestore'ga yozilgan).
  final DateTime? lastSeen;

  // ═══════════════════════ DISPLAY HELPERS ═══════════════════════

  /// UI'ga ko'rsatish uchun model — `null` bo'lsa fallback matn.
  String get displayModel => deviceModel ?? "Noma'lum qurilma";

  /// UI'ga OS — `null` bo'lsa fallback.
  String get displayOS => androidVersion ?? "Noma'lum tizim";

  /// UI'ga ilova versiyasi.
  String get displayAppVersion => appVersion ?? '—';

  /// Batareya matni — foiz + zaryadlanish belgisi.
  String get displayBattery {
    if (batteryLevel == null) return "Noma'lum";
    if (isCharging ?? false) return '$batteryLevel% (zaryadlanmoqda)';
    return '$batteryLevel%';
  }

  /// Wi-Fi nomi — yo'q bo'lsa fallback.
  String get displayWifi => wifiName ?? "Wi-Fi yo'q";

  /// So'nggi faollik vaqtini insonga tushunarli matn qilib qaytaradi
  /// ("Hozir", "5 daq oldin", "2 soat oldin", "3 kun oldin").
  String get displayLastSeen {
    final ts = lastSeen;
    if (ts == null) return 'Hech qachon';
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return 'Hozir';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daq oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${diff.inDays} kun oldin';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChildDeviceInfo &&
        other.deviceModel == deviceModel &&
        other.androidVersion == androidVersion &&
        other.appVersion == appVersion &&
        other.batteryLevel == batteryLevel &&
        other.isCharging == isCharging &&
        other.wifiName == wifiName &&
        other.isOnline == isOnline &&
        other.lastSeen == lastSeen;
  }

  @override
  int get hashCode => Object.hash(
        deviceModel,
        androidVersion,
        appVersion,
        batteryLevel,
        isCharging,
        wifiName,
        isOnline,
        lastSeen,
      );
}
