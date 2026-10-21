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
//
// Maydon darajasida esa `JsonFieldReader`: `json['x'] as String?` server
// maydon turini o'zgartirsa (int, obyekt) TypeError otadi — o'quvchilar
// turini tekshiradi va mos kelmasa zaxira qiymat qaytaradi (hech qachon
// otmaydi).

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

/// Istalgan qiymatni JSON obyektiga aylantiradi; obyekt emas → `null`.
/// Kalitlari satr bo'lmagan yozuvlar tashlanadi.
Map<String, dynamic>? asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is! Map) return null;
  return <String, dynamic>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

/// Server JSON maydonlarini turi tekshirilib o'qish — hech qachon otmaydi.
extension JsonFieldReader on Map<String, dynamic> {
  /// Satr; yo'q yoki satr emas → [fallback].
  String readString(String key, {String fallback = ''}) {
    final value = this[key];
    return value is String ? value : fallback;
  }

  /// Bo'sh bo'lmagan satr; aks holda `null`.
  String? readStringOrNull(String key) {
    final value = this[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Butun son (`num` yoki raqamli satr); aks holda `null`.
  int? readIntOrNull(String key) {
    final value = this[key];
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Butun son; o'qib bo'lmasa [fallback].
  int readInt(String key, {int fallback = 0}) => readIntOrNull(key) ?? fallback;

  /// Mantiqiy qiymat; yo'q yoki bool emas → [fallback].
  bool readBool(String key, {bool fallback = false}) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  /// ISO-8601 vaqt (lokal vaqtga o'giriladi); yo'q yoki buzuq → `null`.
  DateTime? readDateTime(String key) {
    final value = this[key];
    return value is String ? DateTime.tryParse(value)?.toLocal() : null;
  }

  /// Ichki obyekt; yo'q yoki obyekt emas → `null`.
  Map<String, dynamic>? readMapOrNull(String key) => asJsonMap(this[key]);

  /// Ro'yxat; yo'q yoki ro'yxat emas → bo'sh ro'yxat.
  List<dynamic> readList(String key) {
    final value = this[key];
    return value is List ? value : const <dynamic>[];
  }
}
