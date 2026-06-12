// ─────────────────────────────────────────────────────────────────────
// safe_parse — server ro'yxatlarini himoyali parse qilish (ARCH-12)
// ─────────────────────────────────────────────────────────────────────
//
// Muammo: `list.map(Model.fromJson).toList()` — BITTA buzuq element
// (server maydon turini o'zgartirdi, null keldi) butun ro'yxatni
// yiqitadi va ekran bo'sh/error bo'ladi. 100k user + sxema evolyutsiyasida
// bu doimiy xavf.
//
// Yechim: har element alohida try-catch — buzug'i tashlanadi (log bilan),
// qolgani ko'rinadi.

import 'package:flutter/foundation.dart';

/// Xom ro'yxatni element-ma-element xavfsiz parse qiladi.
/// Map bo'lmagan yoki parse'da yiqilgan elementlar TASHLANADI (log).
List<T> parseListSafely<T>(
  Iterable<dynamic> raw,
  T Function(Map<String, dynamic>) fromJson, {
  String? tag,
}) {
  final out = <T>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    try {
      out.add(fromJson(item));
    } catch (e) {
      debugPrint('parseListSafely(${tag ?? T.toString()}): element xato $e');
    }
  }
  return out;
}
