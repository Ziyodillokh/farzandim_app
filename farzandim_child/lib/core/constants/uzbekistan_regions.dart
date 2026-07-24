// ─────────────────────────────────────────────────────────────────────
// UzbekistanRegions — 14 viloyatlar ro'yxati
// ─────────────────────────────────────────────────────────────────────
//
// Bola profilidagi `region` maydoni shu ro'yxatdan tanlanadi.
// `RegionPickerBottomSheet` shu konstantadan o'qiydi.
//
// MUHIM: `all` dagi qiymatlar KANONIK (saqlanadigan/backendga yuboriladigan)
// qiymatlar — ular O'ZGARMAYDI (aks holda saqlangan region va reyting filtri
// buziladi). Ko'p tilli KO'RSATISH uchun `label(canonical)` ishlatiladi:
// u kanonik qiymatni `regions.*` tarjimasiga xaritalaydi, topilmasa
// kanonik qiymatni o'zini qaytaradi (xavfsiz fallback).

import 'package:easy_localization/easy_localization.dart';

class UzbekistanRegions {
  UzbekistanRegions._();

  static const List<String> all = [
    'Toshkent shahri',
    'Toshkent viloyati',
    'Andijon viloyati',
    'Buxoro viloyati',
    "Farg'ona viloyati",
    'Jizzax viloyati',
    'Xorazm viloyati',
    'Namangan viloyati',
    'Navoiy viloyati',
    'Qashqadaryo viloyati',
    'Samarqand viloyati',
    'Sirdaryo viloyati',
    'Surxondaryo viloyati',
    "Qoraqalpog'iston Respublikasi",
  ];

  /// Kanonik region qiymati → `regions.*` tarjima kaliti.
  static const Map<String, String> _slug = {
    'Toshkent shahri': 'tashkentCity',
    'Toshkent viloyati': 'tashkent',
    'Andijon viloyati': 'andijan',
    'Buxoro viloyati': 'bukhara',
    "Farg'ona viloyati": 'fergana',
    'Jizzax viloyati': 'jizzakh',
    'Xorazm viloyati': 'khorezm',
    'Namangan viloyati': 'namangan',
    'Navoiy viloyati': 'navoi',
    'Qashqadaryo viloyati': 'kashkadarya',
    'Samarqand viloyati': 'samarkand',
    'Sirdaryo viloyati': 'sirdarya',
    'Surxondaryo viloyati': 'surkhandarya',
    "Qoraqalpog'iston Respublikasi": 'karakalpakstan',
    // Backend region bermasa ishlatiladigan mamlakat-standarti.
    "O'zbekiston": 'uzbekistan',
  };

  /// Kanonik region qiymatini foydalanuvchi tiliga tarjima qiladi
  /// (faqat KO'RSATISH uchun; saqlanadigan qiymat o'zgarmasin).
  static String label(String canonical) {
    final slug = _slug[canonical];
    return slug == null ? canonical : 'regions.$slug'.tr();
  }
}
