// ─────────────────────────────────────────────────────────────────────
// ChildDeviceInfo — bola qurilmasining ma'lumotlari
// ─────────────────────────────────────────────────────────────────────
//
// DeviceInfoService backendga yuboradigan qiymatlar to'plami.
//
// ⚠️ `wifiName` (SSID) maydoni OLIB TASHLANGAN (2026-08-18) — Google Play
// "Families Device Identifiers" siyosati: faqat bolalarga mo'ljallangan
// ilova SSID/BSSID kabi identifikatorlarni yig'ishi/uzatishi TAQIQLANADI
// (2026-08-17 rad javobining sababi). Qayta qo'shmang.
// Shu tozalashda ishlatilmayotgan `toFirestore()`/`fromFirestore()` ham
// olib tashlandi (loyiha backendga Dio orqali yozadi, Firestore'ga emas).

class ChildDeviceInfo {
  final String? deviceModel;
  final String? androidVersion;
  final String? appVersion;
  final int? batteryLevel;
  final bool? isCharging;
  final bool isOnline;
  final DateTime? lastSeen;

  const ChildDeviceInfo({
    this.deviceModel,
    this.androidVersion,
    this.appVersion,
    this.batteryLevel,
    this.isCharging,
    this.isOnline = false,
    this.lastSeen,
  });
}
