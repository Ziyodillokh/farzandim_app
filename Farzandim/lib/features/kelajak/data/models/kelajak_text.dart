// ─────────────────────────────────────────────────────────────────────
// kelajak_text — Kelajak modellari uchun uch tilli matn o'qish
// ─────────────────────────────────────────────────────────────────────
//
// Backend matnlari `{uz, ru?, en?}` (`texts.ts`); ilova `ru`/`en`
// bo'lmasa o'zbekchani ko'rsatadi — Growth'dagi `LocalizedText` qayta
// ishlatiladi. Majburiy matn yo'q bo'lsa element ro'yxatdan tashlanadi
// (`parseListSafely` xatoni ushlaydi).

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart'
    show LocalizedText;

export 'package:farzandim/features/growth/data/models/learning_result.dart'
    show LocalizedText;

/// Ixtiyoriy matn; yo'q yoki bo'sh → `null`.
LocalizedText? readKelajakText(Map<String, dynamic> json, String key) =>
    LocalizedText.tryParse(json[key]);

/// Majburiy matn; yo'q bo'lsa [FormatException] (element tashlanadi).
LocalizedText requireKelajakText(Map<String, dynamic> json, String key) {
  final text = LocalizedText.tryParse(json[key]);
  if (text == null) throw FormatException('kelajak: "$key" yo`q');
  return text;
}

/// Bo'sh bo'lmagan satr; yo'q bo'lsa [FormatException].
String requireKelajakString(Map<String, dynamic> json, String key) {
  final value = json.readStringOrNull(key);
  if (value == null) throw FormatException('kelajak: "$key" yo`q');
  return value;
}

/// 0–100 oralig'idagi ball (backend normallashtirgan).
int readKelajakScore(Map<String, dynamic> json, String key) =>
    json.readInt(key).clamp(0, 100);

/// Ro'yxatni element-ma-element o'qib, o'zgarmas nusxa qaytaradi.
List<T> readKelajakList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) => List.unmodifiable(
  parseListSafely(json.readList(key), fromJson, tag: 'kelajak.$key'),
);
