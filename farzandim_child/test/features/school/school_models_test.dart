// Maktab modellari JSON'i: server javobi o'qiladi, noma'lum enum qiymati
// `unknown`ga tushadi, buzilgan yozuv istisnosiz tashlab yuboriladi.

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'school_fixtures.dart';

void main() {
  group('SchoolToday', () {
    test('server holati to\'liq o\'qiladi', () {
      final today = SchoolToday.tryFromJson(todayJson)!;
      expect(today.schoolName, 'Parvoz maktabi');
      expect(today.className, '5-A');
      expect(today.date, DateTime(2026, 10, 20));
      expect(today.shift?.start, '08:00');
      expect(today.shift?.end, '13:25');
      expect(today.isSchoolDay, isTrue);
      expect(today.record?.status, AttendanceStatus.late);
      expect(today.record?.source, AttendanceSource.qr);
      expect(today.record?.inAt, '08:12');
      expect(today.record?.outAt, isNull);
      expect(today.canScan, isTrue);
    });

    test('noma\'lum holat / manba — unknown, buzilgan vaqt — null', () {
      final today = SchoolToday.tryFromJson({
        ...todayJson,
        'shift': {'name': 'x', 'start': '8:00', 'end': '13:25'},
        'record': {
          'status': 'TELEPORTED',
          'source': 42,
          'inAt': '25:00',
          'outAt': '13:30',
        },
      })!;
      expect(today.shift, isNull);
      expect(today.record?.status, AttendanceStatus.unknown);
      expect(today.record?.source, AttendanceSource.unknown);
      expect(today.record?.inAt, isNull);
      expect(today.record?.outAt, '13:30');
    });

    test('ixtiyoriy maydonlarsiz ham o\'qiladi', () {
      final today = SchoolToday.tryFromJson({'schoolName': 'Maktab'})!;
      expect(today.className, isNull);
      expect(today.shift, isNull);
      expect(today.record, isNull);
      expect(today.date, isNull);
      // `schoolDay` kelmasa — QR tugmasi yashirilmaydi (server tekshiradi).
      expect(today.isSchoolDay, isTrue);
      expect(SchoolToday.tryFromJson({'className': ''})?.className, isNull);
    });

    test('QR tugmasi: dam olish kuni yoki chiqib ketgandan keyin yo\'q', () {
      final holiday = SchoolToday.tryFromJson({
        ...todayJson,
        'schoolDay': false,
      })!;
      expect(holiday.canScan, isFalse);
      final left = SchoolToday.tryFromJson({
        ...todayJson,
        'record': {'status': 'PRESENT', 'inAt': '07:50', 'outAt': '13:30'},
      })!;
      expect(left.canScan, isFalse);
    });

    test('obyekt bo\'lmasa null', () {
      expect(SchoolToday.tryFromJson(null), isNull);
      expect(SchoolToday.tryFromJson('today'), isNull);
      expect(SchoolToday.tryFromJson(const [1, 2]), isNull);
    });
  });

  test('CheckInResult: IN / OUT / NONE va noma\'lum harakat', () {
    CheckInAction actionOf(Object? wire) =>
        CheckInResult.tryFromJson({'action': wire, 'today': todayJson})!.action;
    expect(actionOf('IN'), CheckInAction.arrived);
    expect(actionOf('OUT'), CheckInAction.departed);
    expect(actionOf('NONE'), CheckInAction.none);
    expect(actionOf('JUMP'), CheckInAction.unknown);
    expect(actionOf(null), CheckInAction.unknown);
    final result = CheckInResult.tryFromJson({'action': 'IN', 'today': 7})!;
    expect(result.today, isNull);
    expect(CheckInResult.tryFromJson('IN'), isNull);
  });

  group('Bola ovozi', () {
    test('so\'rovnoma holatlari', () {
      final active = CareSurveyStatus.tryFromJson(careSurveyJson)!;
      expect(active.isEnrolled, isTrue);
      expect(active.isAnswered, isFalse);
      expect(active.survey?.id, 'survey-1');
      expect(active.survey?.questions.map((q) => q.id), ['q1', 'q2']);

      final answered = CareSurveyStatus.tryFromJson({
        'enrolled': true,
        'survey': null,
        'answered': true,
      })!;
      expect((answered.isAnswered, answered.survey), (true, null));

      final notEnrolled = CareSurveyStatus.tryFromJson({
        'enrolled': false,
        'survey': null,
        'answered': false,
      })!;
      expect(notEnrolled.isEnrolled, isFalse);
      expect(CareSurveyStatus.tryFromJson([]), isNull);
    });

    test('savolsiz so\'rovnoma ko\'rsatilmaydi, takror savol tashlanadi', () {
      final empty = CareSurveyStatus.tryFromJson({
        'enrolled': true,
        'answered': false,
        'survey': {'id': 's', 'title': 't', 'questions': []},
      })!;
      expect(empty.survey, isNull);
      final survey = CareSurvey.tryFromJson({
        'id': 's',
        'questions': [
          {'id': 'q1', 'text': 'a'},
          {'id': 'q1', 'text': 'takror'},
          {'text': 'id yo\'q'},
          'buzilgan',
        ],
      })!;
      expect(survey.questions.single.text, 'a');
    });

    test('murojaat: vaqtlar UTC, noma\'lum qiymatlar unknown', () {
      final request = CareRequest.tryFromJson(careRequestJson)!;
      expect(request.topic, CareTopic.peers);
      expect(request.urgency, CareUrgency.normal);
      expect(request.status, CareRequestStatus.scheduled);
      expect(request.createdAt, DateTime.utc(2026, 10, 19, 6, 30));
      expect(request.meetingAt, DateTime.utc(2026, 10, 21, 9));

      final odd = CareRequest.tryFromJson({
        ...careRequestJson,
        'topic': 'ALIENS',
        'urgency': 'SOMEDAY',
        'status': 'ARCHIVED',
        'meetingAt': 'ertaga',
      })!;
      expect(odd.topic, CareTopic.unknown);
      expect(odd.urgency, CareUrgency.unknown);
      expect(odd.status, CareRequestStatus.unknown);
      expect(odd.meetingAt, isNull);
      expect(CareRequestStatus.fromWire('NEW'), CareRequestStatus.sent);
    });

    test('id yoki sanasiz murojaat tashlanadi', () {
      expect(
        CareRequest.tryFromJson({...careRequestJson, 'createdAt': null}),
        isNull,
      );
      expect(CareRequest.tryFromJson({...careRequestJson, 'id': ''}), isNull);
    });
  });

  group('Psixologik testlar', () {
    test('ro\'yxat elementi', () {
      final summary = PsychAssignmentSummary.tryFromJson(psychSummaryJson)!;
      expect(summary.assignmentId, 'assign-1');
      expect(summary.kind, PsychKind.attention);
      expect(summary.itemCount, 3);
      expect(summary.timeLimitMin, 10);
      expect(summary.closesAt, DateTime.utc(2026, 10, 25, 13));

      final odd = PsychAssignmentSummary.tryFromJson({
        ...psychSummaryJson,
        'kind': 'TELEPATHY',
        'timeLimitMin': null,
        'itemCount': -2,
      })!;
      expect(odd.kind, PsychKind.unknown);
      expect(odd.timeLimitMin, isNull);
      expect(odd.itemCount, 0);
      expect(PsychKind.fromWire('SELF_ESTEEM'), PsychKind.selfEsteem);
    });

    test('test savollari: uch tur, stimul va variantlar', () {
      final psychTest = PsychTest.tryFromJson(psychTestJson)!;
      expect(psychTest.instructions, 'Savollarni diqqat bilan o‘qing');
      expect(psychTest.items.map((i) => i.id), ['s1', 'l1', 'm1']);
      final single = psychTest.items[0] as PsychSingleItem;
      expect(single.options.map((o) => o.key), ['a', 'b']);
      expect(single.stimulus?.showSec, 3);
      expect(psychTest.items[1], isA<PsychLikertItem>());
      expect((psychTest.items[2] as PsychMultiItem).options, hasLength(3));
    });

    test('noma\'lum tur va variantsiz savol tashlanadi', () {
      final psychTest = PsychTest.tryFromJson({
        ...psychTestJson,
        'timeLimitMin': 0,
        'items': [
          {'id': 'd1', 'type': 'DRAWING', 'text': 'Rasm chizing'},
          {'id': 's2', 'type': 'SINGLE', 'text': 'Variantsiz', 'options': []},
          {
            'id': 's3',
            'type': 'SINGLE',
            'text': 'Stimul buzilgan',
            'options': [
              {'key': 'a', 'text': 'A'},
              {'key': 'a', 'text': 'takror'},
              {'text': 'kalitsiz'},
            ],
            'stimulus': {'text': '9', 'showSec': 0},
          },
          {'id': 'l1', 'type': 'LIKERT', 'text': 'a'},
          {'id': 'l1', 'type': 'LIKERT', 'text': 'takror id'},
        ],
      })!;
      expect(psychTest.timeLimitMin, isNull);
      expect(psychTest.items.map((i) => i.id), ['s3', 'l1']);
      final single = psychTest.items.first as PsychSingleItem;
      expect(single.options.single.text, 'A');
      expect(single.stimulus, isNull);
    });

    test('savolsiz yoki id\'siz test — null', () {
      expect(PsychTest.tryFromJson({...psychTestJson, 'items': []}), isNull);
      expect(
        PsychTest.tryFromJson({...psychTestJson, 'assignmentId': null}),
        isNull,
      );
    });
  });

  group('PsychAnswer', () {
    final psychTest = PsychTest.tryFromJson(psychTestJson)!;
    final single = psychTest.items[0];
    final likert = psychTest.items[1];
    final multi = psychTest.items[2];

    test('server shakli', () {
      expect(const PsychSingleAnswer('a').wireValue, 'a');
      expect(const PsychLikertAnswer(4).wireValue, 4);
      expect(PsychMultiAnswer(['x', 'z']).wireValue, ['x', 'z']);
      expect(
        encodePsychAnswers(psychTest, {
          's1': const PsychSingleAnswer('b'),
          'l1': const PsychLikertAnswer(5),
          'm1': PsychMultiAnswer(const []),
        }),
        {'s1': 'b', 'l1': 5, 'm1': <String>[]},
      );
    });

    test('savolga mos kelmaydigan javob rad etiladi', () {
      expect(const PsychSingleAnswer('a').fits(single), isTrue);
      expect(const PsychSingleAnswer('q').fits(single), isFalse);
      expect(const PsychSingleAnswer('a').fits(likert), isFalse);
      expect(const PsychLikertAnswer(1).fits(likert), isTrue);
      expect(const PsychLikertAnswer(0).fits(likert), isFalse);
      expect(const PsychLikertAnswer(6).fits(likert), isFalse);
      expect(PsychMultiAnswer(['x', 'y']).fits(multi), isTrue);
      expect(PsychMultiAnswer(['x', 'x']).fits(multi), isFalse);
      expect(PsychMultiAnswer(['w']).fits(multi), isFalse);
      expect(PsychMultiAnswer(['x']).fits(single), isFalse);
    });

    test('bo\'sh, noma\'lum savol yoki mos kelmasa — yuborilmaydi', () {
      expect(encodePsychAnswers(psychTest, const {}), isNull);
      expect(
        encodePsychAnswers(psychTest, {'zz': const PsychLikertAnswer(3)}),
        isNull,
      );
      expect(
        encodePsychAnswers(psychTest, {
          's1': const PsychSingleAnswer('a'),
          'l1': const PsychLikertAnswer(9),
        }),
        isNull,
      );
    });
  });

  group('SchoolAssignment', () {
    test('test topshirig\'i: fan kichik harfga, bajarilgan', () {
      final a = SchoolAssignment.tryFromJson(schoolAssignmentJson)!;
      expect(a.kind, SchoolAssignmentKind.test);
      expect(a.subject, Subject.math);
      expect(a.dueDate, DateTime(2026, 10, 22));
      expect(a.note, 'Juma kunigacha');
      expect(a.isOverdue, isFalse);
      expect(a.isDone, isTrue);
      expect(a.audiobookId, isNull);
    });

    test('audiokitob: done null, noma\'lum fan va tur', () {
      final book = SchoolAssignment.tryFromJson({
        ...schoolAssignmentJson,
        'kind': 'AUDIOBOOK',
        'materialId': 'audiobook:3f2a',
        'subject': null,
        'done': null,
        'overdue': true,
      })!;
      expect(book.kind, SchoolAssignmentKind.audiobook);
      expect(book.audiobookId, '3f2a');
      expect(book.subject, isNull);
      expect(book.isDone, isNull);
      expect(book.isOverdue, isTrue);

      final odd = SchoolAssignment.tryFromJson({
        ...schoolAssignmentJson,
        'kind': 'PODCAST',
        'subject': 'ASTROLOGY',
        'dueDate': '2026-02-31',
      })!;
      expect(odd.kind, SchoolAssignmentKind.unknown);
      expect(odd.subject, isNull);
      expect(odd.dueDate, isNull);
      expect(SchoolAssignment.tryFromJson({'title': 'id yo\'q'}), isNull);
    });
  });

  test('ro\'yxat yordamchisi buzilgan elementlarni tashlaydi', () {
    final list = jsonList([
      careRequestJson,
      null,
      'x',
      careRequestJson,
    ], CareRequest.tryFromJson);
    expect(list, hasLength(2));
    expect(() => list.add(list.first), throwsUnsupportedError);
    expect(jsonList('not a list', CareRequest.tryFromJson), isEmpty);
    expect(jsonInt(5.0), 5);
    expect(jsonInt(5.5), isNull);
  });
}
