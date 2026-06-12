import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foydalanuvchi birinchi ochilishda ilova tilini tanladimi — onboarding flagi.
///
/// `null` = hali SharedPreferences'dan yuklanmoqda (router redirect kutadi),
/// `false` = tanlanmagan (til tanlash ekrani ko'rsatiladi),
/// `true` = tanlangan (oddiy oqim — welcome/dashboard). Tanlov saqlanadi,
/// keyingi ochilishlarda til ekrani qayta chiqmaydi.
class LanguagePickedNotifier extends StateNotifier<bool?> {
  /// Konstruktor darhol SharedPreferences'dan yuklashni boshlaydi.
  LanguagePickedNotifier() : super(null) {
    _load();
  }

  static const _key = 'app.language_picked.v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // best-effort — xato bo'lsa til ekranini ko'rsatamiz (false)
      state = false;
    }
  }

  /// Til tanlandi — flagni `true` qilib saqlaymiz.
  Future<void> markPicked() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // best-effort — saqlanmasa keyingi ochilishda yana chiqadi (xavfsiz)
    }
  }
}

/// Birinchi ochilish til tanlovi flagi. `null` — yuklanmoqda.
final languagePickedProvider =
    StateNotifierProvider<LanguagePickedNotifier, bool?>(
      (ref) => LanguagePickedNotifier(),
    );
