// Maktab API javoblarini xavfsiz o'qish. Server ma'lumoti ishonchsiz:
// noto'g'ri turdagi qiymat istisno tashlamaydi — `null` yoki zaxira
// qiymat qaytadi, buzilgan ro'yxat elementlari tashlab yuboriladi.

/// Server enum qiymati (`'PRESENT'`, `'IN_PROGRESS'` …).
abstract interface class WireEnum {
  String get wire;
}

/// Server qiymatidan enum; noma'lum yoki noto'g'ri qiymat — [fallback].
T enumFromWire<T extends WireEnum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  for (final item in values) {
    if (item.wire == value) return item;
  }
  return fallback;
}

/// Satr yoki `null`.
String? jsonString(Object? value) => value is String ? value : null;

/// Bo'sh bo'lmagan satr (identifikator, ixtiyoriy nom) yoki `null`.
String? jsonNonEmpty(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

/// Ko'rsatiladigan matn — yo'q bo'lsa bo'sh satr.
String jsonText(Object? value) => value is String ? value : '';

/// Butun son (`3.0` ham) yoki `null`.
int? jsonInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return null;
}

/// ISO vaqt lahzasi (UTC) yoki `null`.
DateTime? jsonInstant(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `"YYYY-MM-DD"` — vaqtsiz sana yoki `null` (`2026-02-31` kabi sana ham).
DateTime? jsonDay(Object? value) {
  final match = value is String ? _dayPattern.firstMatch(value) : null;
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  final isExact = date.year == year && date.month == month && date.day == day;
  return isExact ? date : null;
}

final _clockPattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// `"HH:MM"` (Toshkent devor soati) yoki `null`.
String? jsonClock(Object? value) =>
    value is String && _clockPattern.hasMatch(value) ? value : null;

/// Ro'yxat — o'qib bo'lmagan elementlar tashlab yuboriladi.
List<T> jsonList<T>(Object? value, T? Function(Object? item) parse) =>
    List<T>.unmodifiable(<T>[
      if (value is List)
        for (final item in value) ?parse(item),
    ]);

/// Kalit bo'yicha birinchi uchragani qoladi (takror id/kalitlar tashlanadi).
List<T> uniqueBy<T>(Iterable<T> items, String Function(T item) keyOf) {
  final seen = <String>{};
  return List<T>.unmodifiable(items.where((item) => seen.add(keyOf(item))));
}
