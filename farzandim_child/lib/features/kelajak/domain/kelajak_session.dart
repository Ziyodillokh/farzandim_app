// Kelajak sessiyasi (§4 `SessionView`, `AnswerView`): savollar (faqat
// bolaning yosh guruhidan — server tanlaydi), berilgan javoblar va
// yakundagi natija.

import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_json.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Ochiq javob uzunligi chegarasi (server bilan bir xil).
const kKelajakTextMaxLength = 1000;

/// Shkala varianti.
class KelajakOption {
  const KelajakOption({required this.value, required this.label});

  static KelajakOption? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final value = jsonInt(map?['value']);
    if (map == null || value == null) return null;
    return KelajakOption(
      value: value,
      label: jsonLocalized(map['label']) ?? LocalizedText.same('$value'),
    );
  }

  final int value;
  final LocalizedText label;
}

/// Sessiya savoli.
class KelajakQuestion {
  const KelajakQuestion({
    required this.id,
    required this.text,
    required this.answerType,
    required this.options,
    required this.isRequired,
    this.externalId,
    this.category = '',
    this.categoryName,
    this.maxLength,
  });

  static KelajakQuestion? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonNonEmpty(map?['id']);
    final text = jsonLocalized(map?['text']);
    if (map == null || id == null || text == null) return null;
    final answerType = KelajakAnswerType.fromWire(map['answerType']);
    final required = map['required'];
    return KelajakQuestion(
      id: id,
      text: text,
      answerType: answerType,
      options: jsonList(map['options'], KelajakOption.tryFromJson),
      // Maydon bo'lmasa: shkala — majburiy, ochiq matn — hech qachon.
      isRequired: required is bool
          ? required
          : answerType != KelajakAnswerType.text,
      externalId: jsonNonEmpty(map['externalId']),
      category: jsonText(map['category']),
      categoryName: jsonLocalized(map['categoryName']),
      maxLength: jsonInt(map['maxLength']),
    );
  }

  final String id;
  final LocalizedText text;
  final KelajakAnswerType answerType;
  final List<KelajakOption> options;
  final bool isRequired;

  /// Bank id'si (`PARVOZ-Q034`).
  final String? externalId;
  final String category;
  final LocalizedText? categoryName;

  /// Ochiq javob uzunligi chegarasi (faqat `text`).
  final int? maxLength;

  /// Ochiq (matnli) javob.
  bool get isText => answerType == KelajakAnswerType.text;

  /// Variant tanlanadigan savol (noma'lum tur ham — variantlari bo'lsa).
  bool get isChoice => !isText && options.isNotEmpty;

  /// Ochiq javob uchun amaldagi uzunlik chegarasi.
  int get textLimit => maxLength ?? kKelajakTextMaxLength;

  bool hasOption(int value) => options.any((o) => o.value == value);
}

/// Bitta javob (shkala qiymati yoki ochiq matn).
class KelajakAnswer {
  const KelajakAnswer({required this.questionId, this.value, this.text});

  static KelajakAnswer? tryFromJson(Object? json) {
    final map = jsonMap(json);
    final questionId = jsonNonEmpty(map?['questionId']);
    if (map == null || questionId == null) return null;
    return KelajakAnswer(
      questionId: questionId,
      value: jsonInt(map['value']),
      text: jsonNonEmpty(map['text']),
    );
  }

  final String questionId;
  final int? value;
  final String? text;

  /// Yopiq sessiyada wellbeing / safety qiymati va ochiq matn qaytmaydi
  /// (maxfiylik) — javob bor, lekin mazmuni yashirin.
  bool get isHidden => value == null && text == null;

  @override
  bool operator ==(Object other) =>
      other is KelajakAnswer &&
      other.questionId == questionId &&
      other.value == value &&
      other.text == text;

  @override
  int get hashCode => Object.hash(questionId, value, text);

  @override
  String toString() => 'KelajakAnswer($questionId, $value, $text)';
}

/// Javob saqlangandan keyingi server holati (`AnswerView`).
class KelajakAnswerAck {
  const KelajakAnswerAck({
    required this.questionId,
    required this.sessionStatus,
    required this.answeredCount,
    this.value,
    this.text,
  });

  factory KelajakAnswerAck.fromJson(Object? json) {
    final map = jsonMap(json);
    final questionId = jsonNonEmpty(map?['questionId']);
    if (map == null || questionId == null) {
      throw const FormatException('KelajakAnswerAck: noto\'g\'ri JSON');
    }
    return KelajakAnswerAck(
      questionId: questionId,
      value: jsonInt(map['value']),
      text: jsonNonEmpty(map['text']),
      sessionStatus: KelajakSessionStatus.fromWire(map['sessionStatus']),
      answeredCount: jsonCount(map['answeredCount']),
    );
  }

  final String questionId;
  final int? value;
  final String? text;
  final KelajakSessionStatus sessionStatus;
  final int answeredCount;

  /// Javob o'chirildi (`text: ""` yuborilgan).
  bool get isCleared => value == null && text == null;

  /// Serverdagi javob (o'chirilgan bo'lsa `null`).
  KelajakAnswer? get answer => isCleared
      ? null
      : KelajakAnswer(questionId: questionId, value: value, text: text);
}

/// Bugungi (yoki tarixdagi) sessiya.
class KelajakSession {
  const KelajakSession({
    required this.id,
    required this.type,
    required this.status,
    required this.questions,
    required this.answers,
    this.title,
    this.ageGroup,
    this.day,
    this.startedAt,
    this.completedAt,
    this.total = 0,
    this.answeredCount = 0,
    this.result,
  });

  factory KelajakSession.fromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonNonEmpty(map?['id']);
    final type = jsonNonEmpty(map?['type']);
    if (map == null || id == null || type == null) {
      throw const FormatException('KelajakSession: noto\'g\'ri JSON');
    }
    final questions = uniqueBy(
      jsonList(map['questions'], KelajakQuestion.tryFromJson),
      (q) => q.id,
    );
    final ids = {for (final q in questions) q.id};
    return KelajakSession(
      id: id,
      type: type,
      status: KelajakSessionStatus.fromWire(map['status']),
      questions: questions,
      answers: List.unmodifiable(
        uniqueBy(
          jsonList(map['answers'], KelajakAnswer.tryFromJson),
          (a) => a.questionId,
        ).where((a) => ids.contains(a.questionId)),
      ),
      title: jsonLocalized(map['title']),
      ageGroup: jsonNonEmpty(map['ageGroup']),
      day: jsonDay(map['day']),
      startedAt: jsonInstant(map['startedAt']),
      completedAt: jsonInstant(map['completedAt']),
      total: jsonCount(map['total']),
      answeredCount: jsonCount(map['answeredCount']),
      result: KelajakResult.tryFromJson(map['result']),
    );
  }

  final String id;

  /// Test turi (server qiymati, masalan `daily`).
  final String type;
  final KelajakSessionStatus status;
  final List<KelajakQuestion> questions;

  /// Berilgan javoblar (savol tartibida emas bo'lishi mumkin).
  final List<KelajakAnswer> answers;
  final LocalizedText? title;
  final String? ageGroup;

  /// Toshkent kuni (vaqtsiz sana).
  final DateTime? day;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int total;
  final int answeredCount;

  /// Yakunlangandan keyin.
  final KelajakResult? result;

  KelajakTestType get testType => KelajakTestType.fromWire(type);
  bool get isOpen => status.isOpen;
  bool get isCompleted => status == KelajakSessionStatus.completed;
}
