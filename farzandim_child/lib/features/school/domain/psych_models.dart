// Psixologik testlar (`/child/school/assessments`): maktab psixologi sinfga
// tayinlagan testlar. Bolaga faqat savol va variantlar keladi — to'g'ri
// javob, shkala va ball yuborilmaydi (natija psixolog uchun).

import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Test turi.
enum PsychKind implements WireEnum {
  cognitive('COGNITIVE'),
  attention('ATTENTION'),
  emotional('EMOTIONAL'),
  selfEsteem('SELF_ESTEEM'),
  career('CAREER'),
  social('SOCIAL'),
  custom('CUSTOM'),
  unknown('');

  const PsychKind(this.wire);

  @override
  final String wire;

  static PsychKind fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Musbat vaqt chegarasi (daqiqa) yoki `null` — cheklovsiz.
int? _timeLimit(Object? value) {
  final minutes = jsonInt(value);
  return minutes != null && minutes > 0 ? minutes : null;
}

/// Ro'yxatdagi ochiq test (hali yechilmagan).
class PsychAssignmentSummary {
  const PsychAssignmentSummary({
    required this.assignmentId,
    required this.testId,
    required this.kind,
    required this.title,
    required this.description,
    required this.itemCount,
    this.timeLimitMin,
    this.closesAt,
  });

  static PsychAssignmentSummary? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final assignmentId = jsonNonEmpty(json['assignmentId']);
    if (assignmentId == null) return null;
    final itemCount = jsonInt(json['itemCount']) ?? 0;
    return PsychAssignmentSummary(
      assignmentId: assignmentId,
      testId: jsonText(json['testId']),
      kind: PsychKind.fromWire(json['kind']),
      title: jsonText(json['title']),
      description: jsonText(json['description']),
      itemCount: itemCount < 0 ? 0 : itemCount,
      timeLimitMin: _timeLimit(json['timeLimitMin']),
      closesAt: jsonInstant(json['closesAt']),
    );
  }

  final String assignmentId;
  final String testId;
  final PsychKind kind;
  final String title;
  final String description;
  final int itemCount;

  /// Vaqt chegarasi (daqiqa) — `null`: cheklovsiz.
  final int? timeLimitMin;

  /// Yopilish lahzasi (UTC).
  final DateTime? closesAt;
}

/// Javob varianti.
class PsychOption {
  const PsychOption({required this.key, required this.text});

  static PsychOption? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final key = jsonNonEmpty(json['key']);
    if (key == null) return null;
    return PsychOption(key: key, text: jsonText(json['text']));
  }

  /// Serverga yuboriladigan kalit.
  final String key;
  final String text;
}

/// Savoldan oldin bir necha soniya ko'rsatiladigan matn (xotira testlari).
class PsychStimulus {
  const PsychStimulus({required this.text, required this.showSec});

  static PsychStimulus? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final showSec = jsonInt(json['showSec']);
    if (showSec == null || showSec <= 0) return null;
    return PsychStimulus(text: jsonText(json['text']), showSec: showSec);
  }

  final String text;

  /// Ko'rsatish davomiyligi (soniya).
  final int showSec;
}

List<PsychOption> _options(Object? json) =>
    uniqueBy(jsonList(json, PsychOption.tryFromJson), (o) => o.key);

/// Test savoli: bitta variant, 1–5 shkala yoki bir nechta variant.
sealed class PsychItem {
  const PsychItem({required this.id, required this.text});

  /// Noma'lum tur yoki variantsiz savol — `null` (ko'rsatilmaydi va
  /// yuborilmaydi; server javobsiz savolni "o'tkazilgan" deb hisoblaydi).
  static PsychItem? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    if (id == null) return null;
    final text = jsonText(json['text']);
    switch (json['type']) {
      case 'LIKERT':
        return PsychLikertItem(id: id, text: text);
      case 'SINGLE':
        final options = _options(json['options']);
        if (options.isEmpty) return null;
        return PsychSingleItem(
          id: id,
          text: text,
          options: options,
          stimulus: PsychStimulus.tryFromJson(json['stimulus']),
        );
      case 'MULTI':
        final options = _options(json['options']);
        if (options.isEmpty) return null;
        return PsychMultiItem(id: id, text: text, options: options);
      default:
        return null;
    }
  }

  final String id;
  final String text;
}

/// Bitta variant tanlanadi.
final class PsychSingleItem extends PsychItem {
  const PsychSingleItem({
    required super.id,
    required super.text,
    required this.options,
    this.stimulus,
  });

  final List<PsychOption> options;
  final PsychStimulus? stimulus;
}

/// 1 (hech qachon) … 5 (doim) shkala.
final class PsychLikertItem extends PsychItem {
  const PsychLikertItem({required super.id, required super.text});
}

/// Bir nechta variant (bo'sh tanlov ham javob).
final class PsychMultiItem extends PsychItem {
  const PsychMultiItem({
    required super.id,
    required super.text,
    required this.options,
  });

  final List<PsychOption> options;
}

/// Yechish uchun test (`GET /child/school/assessments/{id}`).
class PsychTest {
  const PsychTest({
    required this.assignmentId,
    required this.testId,
    required this.kind,
    required this.title,
    required this.description,
    required this.instructions,
    required this.items,
    this.timeLimitMin,
    this.closesAt,
  });

  /// Id yoki ko'rsatsa bo'ladigan savol bo'lmasa `null`.
  static PsychTest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final assignmentId = jsonNonEmpty(json['assignmentId']);
    final items = uniqueBy(
      jsonList(json['items'], PsychItem.tryFromJson),
      (item) => item.id,
    );
    if (assignmentId == null || items.isEmpty) return null;
    return PsychTest(
      assignmentId: assignmentId,
      testId: jsonText(json['testId']),
      kind: PsychKind.fromWire(json['kind']),
      title: jsonText(json['title']),
      description: jsonText(json['description']),
      instructions: jsonText(json['instructions']),
      items: items,
      timeLimitMin: _timeLimit(json['timeLimitMin']),
      closesAt: jsonInstant(json['closesAt']),
    );
  }

  final String assignmentId;
  final String testId;
  final PsychKind kind;
  final String title;
  final String description;
  final String instructions;
  final List<PsychItem> items;

  /// Vaqt chegarasi (daqiqa) — `null`: cheklovsiz.
  final int? timeLimitMin;

  /// Yopilish lahzasi (UTC).
  final DateTime? closesAt;
}
