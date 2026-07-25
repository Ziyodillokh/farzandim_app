// ─────────────────────────────────────────────────────────────────────
// ConsentStorage — SharedPreferences orqali Parent Consent flag
// ─────────────────────────────────────────────────────────────────────
//
// App Store / Play Store compliance talabi: bola ilovasi birinchi
// ochilganda ota-ona aniq roziligi olinishi kerak. Bu rozilik faqat
// BIR MARTA so'raladi va lokal qurilmada saqlanadi.
//
// Versioning (`_v1`) — kelajakda rozilik matni o'zgarsa, yangi kalit
// (`parent_consent_v2`) bilan qayta so'rash mumkin.

import 'package:shared_preferences/shared_preferences.dart';

class ConsentStorage {
  ConsentStorage._();

  static const String _kParentConsentV1 = 'parent_consent_v1';
  static const String _kParentConsentAtMs = 'parent_consent_at_ms';

  /// Rozilik berilganmi? `false` — Consent screen ko'rsatish kerak.
  static Future<bool> isParentConsentGiven() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kParentConsentV1) ?? false;
  }

  /// Rozilik berildi — flag + timestamp saqlanadi.
  /// Timestamp keyinchalik audit/analytics uchun foydali.
  static Future<void> markConsentGiven() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kParentConsentV1, true);
    await prefs.setInt(
      _kParentConsentAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Roziliklikni bekor qilish (test/debug uchun).
  static Future<void> resetConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kParentConsentV1);
    await prefs.remove(_kParentConsentAtMs);
  }

  /// Rozilik qachon berilgan (audit). `null` — hali berilmagan.
  static Future<DateTime?> consentGivenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kParentConsentAtMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
