// ─────────────────────────────────────────────────────────────────────
// RestrictionsSync — ota-ona cheklovlarini qurilmaga qo'llash (umumiy API)
// ─────────────────────────────────────────────────────────────────────
//
// Android: RestrictionsSyncService (native RestrictionService uchun prefs).
// iOS:     IosRestrictionsSyncService (Family Controls, qurilmaning o'zida).
// Chaqiruvchilar (pairing, WS, FCM) qaysi platforma ekanini bilmaydi.

abstract interface class RestrictionsSync {
  /// Pairing tugagach chaqiriladi — darhol sync + davriy yangilash.
  void start({required String childId});

  /// WS/FCM hodisasida darhol yangilash.
  Future<void> sync();

  void dispose();
}
