// Bola ovozi (H01–H10) ma'lumotlari: anonim oylik so'rov, mas'ul psixolog
// (ism, ish vaqti, o'rinbosar) va shaxsiy murojaatlar yozishmasi
// (`/child/school/care/*`, docs/BOLA-OVOZI-API.md).
//
// Anonim so'rov javoblari bu modellarning hech biriga tushmaydi: murojaat va
// yozishma — alohida, shaxsi aniq yo'l.

import 'package:farzandim_child/features/school/domain/school_json.dart';

/// So'rov bahosi: 1 ("yo'q") … 5 ("ha, juda") — server shkalasi.
const kVoiceScoreMin = 1;
const kVoiceScoreMax = 5;

/// Murojaat va xabar matni chegarasi (belgi, server bilan bir xil).
const kVoiceMessageMaxLength = 1000;

/// Oylik anonim so'rov savoli.
class VoiceQuestion {
  const VoiceQuestion({required this.id, required this.text});

  static VoiceQuestion? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    if (id == null) return null;
    return VoiceQuestion(id: id, text: jsonText(json['text']));
  }

  final String id;
  final String text;
}

/// Faol anonim so'rov.
class VoiceSurvey {
  const VoiceSurvey({
    required this.id,
    required this.title,
    required this.questions,
    required this.estimatedMinutes,
    this.activatedAt,
  });

  /// Id yoki savollari bo'lmasa `null`.
  static VoiceSurvey? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final questions = uniqueBy(
      jsonList(json['questions'], VoiceQuestion.tryFromJson),
      (q) => q.id,
    );
    if (id == null || questions.isEmpty) return null;
    final minutes = jsonInt(json['estimatedMinutes']);
    return VoiceSurvey(
      id: id,
      title: jsonText(json['title']),
      questions: questions,
      estimatedMinutes: minutes != null && minutes > 0
          ? minutes
          : (questions.length * 15 / 60).ceil().clamp(1, 60),
      activatedAt: jsonInstant(json['activatedAt']),
    );
  }

  final String id;
  final String title;
  final List<VoiceQuestion> questions;
  final int estimatedMinutes;

  /// Ochilgan lahza — so'rov oyi shundan olinadi.
  final DateTime? activatedAt;
}

/// `GET /child/school/care/survey`.
class VoiceSurveyState {
  const VoiceSurveyState({required this.answered, this.survey});

  static const none = VoiceSurveyState(answered: false);

  static VoiceSurveyState fromJson(Object? json) {
    if (json is! Map) return none;
    final answered = json['answered'] == true;
    return VoiceSurveyState(
      answered: answered,
      // Javob berilgan bo'lsa so'rov qayta ko'rsatilmaydi (server 409 beradi).
      survey: answered ? null : VoiceSurvey.tryFromJson(json['survey']),
    );
  }

  /// Joriy so'rovga allaqachon javob berilgan.
  final bool answered;

  /// Javob kutayotgan so'rov — `null`: hozir yo'q yoki javob berilgan.
  final VoiceSurvey? survey;
}

/// Psixolog ish vaqti (Toshkent): hafta kunlari 1 (Du) … 7 (Ya).
class VoiceHours {
  const VoiceHours({
    required this.days,
    required this.start,
    required this.end,
  });

  static VoiceHours? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final start = jsonClock(json['start']);
    final end = jsonClock(json['end']);
    final raw = json['days'];
    final days = raw is List
        ? ({
            for (final d in raw)
              if (d is int && d >= 1 && d <= 7) d,
          }.toList()..sort())
        : const <int>[];
    if (start == null || end == null || days.isEmpty) return null;
    return VoiceHours(days: days, start: start, end: end);
  }

  final List<int> days;
  final String start;
  final String end;
}

/// Mas'ul psixolog (`GET /child/school/care/contact`).
class VoiceContact {
  const VoiceContact({
    this.psychologistName,
    this.deputyName,
    this.hours,
    this.openNow = false,
    this.nextOpenAt,
  });

  static const unknown = VoiceContact();

  static VoiceContact fromJson(Object? json) {
    if (json is! Map) return unknown;
    String? name(Object? person) =>
        person is Map ? jsonNonEmpty(person['name']) : null;
    return VoiceContact(
      psychologistName: name(json['psychologist']),
      deputyName: name(json['deputy']),
      hours: VoiceHours.tryFromJson(json['hours']),
      openNow: json['openNow'] == true,
      nextOpenAt: jsonInstant(json['nextOpenAt']),
    );
  }

  /// Bolaga ko'rinadigan ism («Dilnoza opa») — `null`: sozlanmagan.
  final String? psychologistName;
  final String? deputyName;
  final VoiceHours? hours;
  final bool openNow;
  final DateTime? nextOpenAt;
}

/// Murojaat bosqichi: qabul qilindi → psixolog ochdi → javob keldi → yopildi.
enum VoiceStage implements WireEnum {
  received('RECEIVED'),
  opened('OPENED'),
  replied('REPLIED'),
  closed('CLOSED');

  const VoiceStage(this.wire);

  @override
  final String wire;

  static VoiceStage fromWire(Object? value) =>
      enumFromWire(values, value, received);
}

/// Ro'yxatdagi murojaat (matnsiz — sarlavha neytral: «Murojaat · sana»).
class VoiceRequestSummary {
  const VoiceRequestSummary({
    required this.id,
    required this.urgent,
    required this.stage,
    required this.createdAt,
    this.unread = 0,
  });

  static VoiceRequestSummary? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final createdAt = jsonInstant(json['createdAt']);
    if (id == null || createdAt == null) return null;
    final unread = jsonInt(json['unread']) ?? 0;
    return VoiceRequestSummary(
      id: id,
      urgent: json['urgency'] == 'URGENT',
      stage: VoiceStage.fromWire(json['stage']),
      createdAt: createdAt,
      unread: unread < 0 ? 0 : unread,
    );
  }

  final String id;
  final bool urgent;
  final VoiceStage stage;
  final DateTime createdAt;

  /// Psixologning o'qilmagan xabarlari.
  final int unread;
}

/// Yozishmadagi xabar.
class VoiceMessage {
  const VoiceMessage({
    required this.id,
    required this.fromChild,
    required this.text,
    required this.createdAt,
    this.authorName,
  });

  static VoiceMessage? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final createdAt = jsonInstant(json['createdAt']);
    final text = jsonText(json['text']);
    if (id == null || createdAt == null || text.trim().isEmpty) return null;
    return VoiceMessage(
      id: id,
      fromChild: json['author'] == 'CHILD',
      text: text,
      createdAt: createdAt,
      authorName: jsonNonEmpty(json['authorName']),
    );
  }

  final String id;
  final bool fromChild;
  final String text;
  final DateTime createdAt;
  final String? authorName;
}

/// Murojaat tafsiloti va yozishma (`GET …/requests/:id`).
class VoiceRequest {
  const VoiceRequest({
    required this.id,
    required this.urgent,
    required this.stage,
    required this.createdAt,
    required this.messages,
    this.openedAt,
    this.repliedAt,
    this.resolvedAt,
    this.meetingAt,
    this.handlerName,
    this.handlerIsDeputy = false,
  });

  static VoiceRequest? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final createdAt = jsonInstant(json['createdAt']);
    if (id == null || createdAt == null) return null;
    final handler = json['handler'];
    final messages = [
      ...uniqueBy(
        jsonList(json['messages'], VoiceMessage.tryFromJson),
        (m) => m.id,
      ),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return VoiceRequest(
      id: id,
      urgent: json['urgency'] == 'URGENT',
      stage: VoiceStage.fromWire(json['stage']),
      createdAt: createdAt,
      messages: List.unmodifiable(messages),
      openedAt: jsonInstant(json['openedAt']),
      repliedAt: jsonInstant(json['repliedAt']),
      resolvedAt: jsonInstant(json['resolvedAt']),
      meetingAt: jsonInstant(json['meetingAt']),
      handlerName: handler is Map ? jsonNonEmpty(handler['name']) : null,
      handlerIsDeputy: handler is Map && handler['isDeputy'] == true,
    );
  }

  final String id;
  final bool urgent;
  final VoiceStage stage;
  final DateTime createdAt;
  final List<VoiceMessage> messages;
  final DateTime? openedAt;
  final DateTime? repliedAt;
  final DateTime? resolvedAt;
  final DateTime? meetingAt;

  /// Murojaatni ko'radigan mutaxassis (o'rinbosarga o'tgan bo'lsa — u).
  final String? handlerName;
  final bool handlerIsDeputy;

  VoiceRequest withMessage(VoiceMessage message) => VoiceRequest(
    id: id,
    urgent: urgent,
    stage: stage,
    createdAt: createdAt,
    messages: List.unmodifiable([
      ...messages.where((m) => m.id != message.id),
      message,
    ]),
    openedAt: openedAt,
    repliedAt: repliedAt,
    resolvedAt: resolvedAt,
    meetingAt: meetingAt,
    handlerName: handlerName,
    handlerIsDeputy: handlerIsDeputy,
  );
}
