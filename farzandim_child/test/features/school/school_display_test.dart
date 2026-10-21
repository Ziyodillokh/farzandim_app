// Ko'rsatish qoidalari (sof funksiyalar): teskari sanoq, test oxirgi kuni
// (Toshkent vaqti), eng yaqin suhbat, shkala belgilari va mavzular.

import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:flutter_test/flutter_test.dart';

CareRequest _request(
  String id, {
  CareRequestStatus status = CareRequestStatus.scheduled,
  DateTime? meetingAt,
}) => CareRequest(
  id: id,
  topic: CareTopic.peers,
  urgency: CareUrgency.normal,
  status: status,
  createdAt: DateTime.utc(2026, 10, 1),
  meetingAt: meetingAt,
);

void main() {
  test('teskari sanoq: soniyalar yuqoriga yaxlitlanadi', () {
    expect(formatCountdown(const Duration(minutes: 10)), '10:00');
    expect(formatCountdown(const Duration(milliseconds: 599200)), '10:00');
    expect(formatCountdown(const Duration(seconds: 59)), '00:59');
    expect(formatCountdown(const Duration(milliseconds: 1)), '00:01');
    expect(formatCountdown(Duration.zero), '00:00');
    expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    expect(formatCountdown(const Duration(hours: 1, minutes: 5)), '1:05:00');
  });

  test('test oxirgi kuni Toshkent vaqtida; yarim tun — oldingi kun', () {
    // 13:00Z = 18:00 Toshkent.
    final evening = psychLastDay(DateTime.utc(2026, 10, 25, 13));
    expect((evening.month, evening.day), (10, 25));
    // 19:00Z = 00:00 Toshkent (26-oktabr) — bola uchun 25-oktabrgacha.
    final midnight = psychLastDay(DateTime.utc(2026, 10, 25, 19));
    expect((midnight.month, midnight.day), (10, 25));
    // 19:30Z = 00:30 Toshkent — haqiqatan 26-oktabr.
    final afterMidnight = psychLastDay(DateTime.utc(2026, 10, 25, 19, 30));
    expect((afterMidnight.month, afterMidnight.day), (10, 26));
  });

  test('eng yaqin suhbat: faqat belgilangan va hali o\'tmagan', () {
    final now = DateTime.utc(2026, 10, 20, 8);
    final past = _request('past', meetingAt: DateTime.utc(2026, 10, 19, 9));
    final later = _request('later', meetingAt: DateTime.utc(2026, 10, 23, 9));
    final soon = _request('soon', meetingAt: DateTime.utc(2026, 10, 21, 9));
    final resolved = _request(
      'resolved',
      status: CareRequestStatus.resolved,
      meetingAt: DateTime.utc(2026, 10, 20, 10),
    );
    final noTime = _request('no-time');

    expect(nextMeeting([past, later, resolved, soon, noTime], now)?.id, 'soon');
    expect(nextMeeting([past, resolved, noTime], now), isNull);
    expect(nextMeeting(const [], now), isNull);
  });

  test('so\'rovnoma shkalasi: 1..5, har biriga alohida belgi', () {
    expect(surveyScaleValues, [1, 2, 3, 4, 5]);
    expect(surveyScaleValues.map(surveyScaleEmoji).toSet(), hasLength(5));
    // Chegaradan tashqari qiymat ham xatosiz.
    expect(surveyScaleEmoji(0), surveyScaleEmoji(1));
    expect(surveyScaleEmoji(9), surveyScaleEmoji(5));
    expect(surveyScaleLabelKey(3), 'school.survey.scale.3');
  });

  test('LIKERT 1..5 va test turi kalitlari', () {
    expect(likertValues, [1, 2, 3, 4, 5]);
    expect(likertLabelKey(2), 'school.psych.likert.2');
    expect(
      psychKindLabelKey(PsychKind.selfEsteem),
      'school.psych.kinds.selfEsteem',
    );
  });

  test('murojaat mavzulari: panel bilan bir xil 7 ta, noma\'lumsiz', () {
    expect(selectableCareTopics.map((t) => t.wire), [
      'LEARNING',
      'PEERS',
      'BULLYING',
      'FAMILY',
      'EMOTIONS',
      'SAFETY',
      'OTHER',
    ]);
    expect(careTopicLabelKey(CareTopic.peers), 'school.requests.topics.peers');
    expect(
      careStatusLabelKey(CareRequestStatus.inProgress),
      'school.requests.status.inProgress',
    );
  });
}
