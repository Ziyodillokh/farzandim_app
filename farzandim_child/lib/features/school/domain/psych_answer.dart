// Psixologik test javoblari — server shakli (`POST …/submit`): SINGLE —
// variant kaliti, LIKERT — 1..5 butun son, MULTI — takrorlanmas kalitlar
// (ko'pi bilan 5 ta; bo'sh ro'yxat ham javob). Javobsiz savol yuborilmaydi —
// server uni "o'tkazilgan" deb hisoblaydi. Javoblar faqat xotirada turadi.

import 'package:farzandim_child/features/school/domain/psych_models.dart';

/// LIKERT shkalasi: 1 (hech qachon) … 5 (doim).
const kLikertMin = 1;
const kLikertMax = 5;

/// MULTI javobidagi kalitlar chegarasi.
const kMaxMultiChoices = 5;

/// Bitta testdagi javoblar chegarasi (server bilan bir xil).
const kMaxPsychAnswers = 60;

/// Bitta savolga javob.
sealed class PsychAnswer {
  const PsychAnswer();

  /// Server JSON qiymati.
  Object get wireValue;

  /// [item] turiga mos va qiymati uning variantlari / shkalasi ichida.
  bool fits(PsychItem item);
}

/// SINGLE — tanlangan variant kaliti.
final class PsychSingleAnswer extends PsychAnswer {
  const PsychSingleAnswer(this.key);

  final String key;

  @override
  Object get wireValue => key;

  @override
  bool fits(PsychItem item) =>
      item is PsychSingleItem && item.options.any((o) => o.key == key);
}

/// LIKERT — 1..5.
final class PsychLikertAnswer extends PsychAnswer {
  const PsychLikertAnswer(this.value);

  final int value;

  @override
  Object get wireValue => value;

  @override
  bool fits(PsychItem item) =>
      item is PsychLikertItem && value >= kLikertMin && value <= kLikertMax;
}

/// MULTI — tanlangan variantlar kalitlari.
final class PsychMultiAnswer extends PsychAnswer {
  PsychMultiAnswer(Iterable<String> keys) : keys = List.unmodifiable(keys);

  final List<String> keys;

  @override
  Object get wireValue => keys;

  @override
  bool fits(PsychItem item) =>
      item is PsychMultiItem &&
      keys.length <= kMaxMultiChoices &&
      keys.toSet().length == keys.length &&
      keys.every((key) => item.options.any((o) => o.key == key));
}

/// Javoblar → server `answers` obyekti. Bo'sh, noma'lum savol yoki savolga
/// mos kelmaydigan javob bo'lsa `null` (yuborilmaydi).
Map<String, Object>? encodePsychAnswers(
  PsychTest test,
  Map<String, PsychAnswer> answers,
) {
  if (answers.isEmpty || answers.length > kMaxPsychAnswers) return null;
  final items = {for (final item in test.items) item.id: item};
  final encoded = <String, Object>{};
  for (final MapEntry(:key, :value) in answers.entries) {
    final item = items[key];
    if (item == null || !value.fits(item)) return null;
    encoded[key] = value.wireValue;
  }
  return Map.unmodifiable(encoded);
}
