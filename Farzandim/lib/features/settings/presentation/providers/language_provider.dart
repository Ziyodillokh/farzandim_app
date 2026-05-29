import 'package:flutter/widgets.dart';

/// Til kodlari (`uz`, `ru`, `en`) bilan ishlash uchun enum.
///
/// **Sprint 3.3**: lokalizatsiya `easy_localization` orqali ishlaydi.
/// Joriy tilni `context.locale.languageCode` orqali olish va
/// `context.setLocale(...)` orqali o'zgartirish kerak. Bu yerda
/// faqat ko'rsatish uchun label va flag saqlanadi.
enum AppLanguage {
  /// O'zbek — default.
  uz('uz', "O'zbekcha", '🇺🇿'),

  /// Rus — O'zbekistondagi ikkinchi til.
  ru('ru', 'Русский', '🇷🇺'),

  /// Ingliz.
  en('en', 'English', '🇺🇸');

  const AppLanguage(this.code, this.label, this.flag);

  /// ISO kod (`uz`, `ru`, `en`).
  final String code;

  /// Foydalanuvchiga ko'rsatiladigan nom (har til o'z nomida).
  final String label;

  /// Bayroq emoji.
  final String flag;

  /// Locale kodidan AppLanguage'ga aylantirish. Topilmasa `uz`.
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.uz,
    );
  }

  /// Locale obyektiga aylantirish.
  Locale get locale => Locale(code);
}
