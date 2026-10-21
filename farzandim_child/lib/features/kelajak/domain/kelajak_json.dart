// Kelajak javoblarini xavfsiz o'qish (umumiy yordamchilar —
// `school_json.dart`; bu yerda faqat Kelajakka xoslari). Noto'g'ri
// qiymat istisno tashlamaydi: `null` yoki zaxira qiymat qaytadi.

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Uch tilli matn (`{uz, ru?, en?}`) yoki `null`.
LocalizedText? jsonLocalized(Object? value) {
  if (value == null) return null;
  try {
    return LocalizedText.fromJson(value);
  } on FormatException {
    return null;
  }
}

/// Ball (0–100, server yaxlitlaydi; kasr kelsa ham yaxlitlanadi) yoki `null`.
int? jsonScore(Object? value) =>
    value is num && value.isFinite ? value.round() : null;

/// Manfiy bo'lmagan son (hisoblagich), yo'q bo'lsa 0.
int jsonCount(Object? value) {
  final count = jsonInt(value);
  return count == null || count < 0 ? 0 : count;
}

/// Bo'sh bo'lmagan satrlar ro'yxati (kodlar, id'lar).
List<String> jsonStrings(Object? value) => jsonList(value, jsonNonEmpty);

/// JSON obyekti yoki `null`.
Map<String, dynamic>? jsonMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;
