// Uch tilli matn (uz/ru/en) — savollar banki va saqlangan natijalar uchun.

/// Ilova tillari; birinchisi — zaxira til.
const kLearningLanguages = ['uz', 'ru', 'en'];

/// Bir nechta tildagi matn. Kerakli til bo'lmasa o'zbekchasi, u ham
/// bo'lmasa birinchi mavjudi qaytadi.
class LocalizedText {
  const LocalizedText(this.values);

  /// Barcha tillarda bir xil matn.
  LocalizedText.same(String text)
    : values = {for (final l in kLearningLanguages) l: text};

  /// JSON obyekti (`{"uz": "...", "ru": "..."}`) yoki oddiy satr.
  factory LocalizedText.fromJson(Object? json) {
    if (json is String) return LocalizedText.same(json);
    if (json is! Map) throw const FormatException('LocalizedText: map kerak');
    final values = <String, String>{
      for (final entry in json.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
    if (values.isEmpty) throw const FormatException('LocalizedText: bo\'sh');
    return LocalizedText(Map.unmodifiable(values));
  }

  final Map<String, String> values;

  String of(String languageCode) =>
      values[languageCode] ??
      values[kLearningLanguages.first] ??
      values.values.first;

  Map<String, String> toJson() => values;

  @override
  bool operator ==(Object other) {
    if (other is! LocalizedText || other.values.length != values.length) {
      return false;
    }
    for (final entry in values.entries) {
      if (other.values[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
