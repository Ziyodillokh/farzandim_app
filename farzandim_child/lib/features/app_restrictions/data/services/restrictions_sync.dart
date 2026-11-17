// ─────────────────────────────────────────────────────────────────────
// RestrictionsSync — ota-ona cheklovlarini qurilmaga qo'llash (umumiy API)
// ─────────────────────────────────────────────────────────────────────
//
// Android: RestrictionsSyncService (native RestrictionService uchun prefs).
// iOS:     IosRestrictionsSyncService (Family Controls, qurilmaning o'zida).
// Chaqiruvchilar (pairing, WS, FCM) qaysi platforma ekanini bilmaydi.

abstract interface class RestrictionsSync {
  /// Pairing tugagach chaqiriladi — darhol sync. Android'da davriy so'rov
  /// yo'q (BackgroundJobs tick/ekran/push), iOS'da — 5 daqiqalik taymer.
  void start({required String childId});

  /// WS/FCM hodisasida darhol yangilash (Android: 2 s ichidagi turtkilar
  /// bittaga yig'iladi).
  Future<void> sync();

  void dispose();
}
