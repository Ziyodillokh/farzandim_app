// "Bola ovozi" (`/child/school/care/*`): maktab so'rovnomasi va psixologga
// murojaatlar. So'rovnoma javoblari anonim — maktab faqat kamida 5
// o'quvchilik guruh natijasini ko'radi; murojaatni faqat psixolog o'qiydi.

import 'package:farzandim_child/features/school/domain/school_json.dart';

/// So'rovnoma bahosi: 1 ("yo'q") … 5 ("ha, juda") — rozilik darajasi, "yaxshi
/// / yomon" emas: teskari savollarda ("seni ranjitishdimi?") yuqori javob
/// yomon holat, server uni o'zi aylantiradi.
const kSurveyScoreMin = 1;
const kSurveyScoreMax = 5;

/// So'rovnomadagi savollar chegarasi (server bilan bir xil).
const kMaxSurveyQuestions = 12;

/// Murojaat matni chegarasi (belgi).
const kCareMessageMaxLength = 1000;

/// So'rovnoma savoli (bola tilida: ru yoki uz).
class CareQuestion {
  const CareQuestion({required this.id, required this.text});

  static CareQuestion? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    if (id == null) return null;
    return CareQuestion(id: id, text: jsonText(json['text']));
  }

  final String id;
  final String text;
}

/// Faol so'rovnoma.
class CareSurvey {
  const CareSurvey({
    required this.id,
    required this.title,
    required this.questions,
  });

  /// Id yoki savollari bo'lmasa `null` (bo'sh so'rovnoma ko'rsatilmaydi).
  static CareSurvey? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final questions = uniqueBy(
      jsonList(json['questions'], CareQuestion.tryFromJson),
      (q) => q.id,
    );
    if (id == null || questions.isEmpty) return null;
    return CareSurvey(
      id: id,
      title: jsonText(json['title']),
      questions: questions,
    );
  }

  final String id;
  final String title;
  final List<CareQuestion> questions;
}

/// So'rovnoma holati (`GET /child/school/care/survey`).
class CareSurveyStatus {
  const CareSurveyStatus({
    required this.isEnrolled,
    required this.isAnswered,
    this.survey,
  });

  /// Maktabga bog'lanmagan.
  static const notEnrolled = CareSurveyStatus(
    isEnrolled: false,
    isAnswered: false,
  );

  static CareSurveyStatus? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final survey = CareSurvey.tryFromJson(json['survey']);
    return CareSurveyStatus(
      isEnrolled: json['enrolled'] == true,
      isAnswered: survey == null && json['answered'] == true,
      survey: survey,
    );
  }

  final bool isEnrolled;

  /// Faol so'rovnomaga allaqachon javob berilgan.
  final bool isAnswered;

  /// Javob kutayotgan so'rovnoma — `null`: hozir yo'q.
  final CareSurvey? survey;
}

/// Murojaat mavzusi (panel `careTopicTag` bilan bir xil).
enum CareTopic implements WireEnum {
  learning('LEARNING'),
  peers('PEERS'),
  bullying('BULLYING'),
  family('FAMILY'),
  emotions('EMOTIONS'),
  safety('SAFETY'),
  other('OTHER'),
  unknown('');

  const CareTopic(this.wire);

  @override
  final String wire;

  static CareTopic fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Murojaat shoshilinchligi.
enum CareUrgency implements WireEnum {
  normal('NORMAL'),
  urgent('URGENT'),
  unknown('');

  const CareUrgency(this.wire);

  @override
  final String wire;

  static CareUrgency fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Murojaat holati.
enum CareRequestStatus implements WireEnum {
  /// `NEW` — yuborilgan, psixolog hali ko'rib chiqmagan.
  sent('NEW'),
  inProgress('IN_PROGRESS'),

  /// Suhbat vaqti belgilangan (`CareRequest.meetingAt`).
  scheduled('SCHEDULED'),
  resolved('RESOLVED'),
  unknown('');

  const CareRequestStatus(this.wire);

  @override
  final String wire;

  static CareRequestStatus fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Bolaning psixologga murojaati (matnsiz — u faqat psixologda).
class CareRequest {
  const CareRequest({
    required this.id,
    required this.topic,
    required this.urgency,
    required this.status,
    required this.createdAt,
    this.meetingAt,
  });

  /// Id yoki yaratilgan vaqt bo'lmasa `null`.
  static CareRequest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final createdAt = jsonInstant(json['createdAt']);
    if (id == null || createdAt == null) return null;
    return CareRequest(
      id: id,
      topic: CareTopic.fromWire(json['topic']),
      urgency: CareUrgency.fromWire(json['urgency']),
      status: CareRequestStatus.fromWire(json['status']),
      createdAt: createdAt,
      meetingAt: jsonInstant(json['meetingAt']),
    );
  }

  final String id;
  final CareTopic topic;
  final CareUrgency urgency;
  final CareRequestStatus status;

  /// Yuborilgan lahza (UTC).
  final DateTime createdAt;

  /// Suhbat lahzasi (UTC) — Toshkent vaqtida ko'rsatiladi (`toTashkent`).
  final DateTime? meetingAt;
}
