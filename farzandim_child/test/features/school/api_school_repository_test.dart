// Server manbai: yo'llar, so'rov tanasi, javob o'qilishi, kirishni so'rovsiz
// tekshirish va xato kodlari (404 kodsiz — funksiya hali yo'q).

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/school/data/api_school_repository.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/network/fake_http_adapter.dart';
import 'school_fixtures.dart';

(ApiSchoolRepository, List<RequestOptions>) repo(
  (int, Object?) Function(RequestOptions options) respond,
) {
  final requests = <RequestOptions>[];
  final dio =
      Dio(
          BaseOptions(
            baseUrl: 'https://api.test/api',
            validateStatus: (s) => s != null && s >= 200 && s < 300,
          ),
        )
        ..httpClientAdapter = FakeHttpAdapter((options) {
          requests.add(options);
          return respond(options);
        });
  return (ApiSchoolRepository(dio), requests);
}

Matcher throwsSchool(SchoolErrorCode code) =>
    throwsA(isA<SchoolException>().having((e) => e.code, 'code', code));

void main() {
  test('bugungi holat: bog\'lanmagan (null) va to\'liq javob', () async {
    var linked = false;
    final (api, requests) = repo(
      (_) => (200, {'today': linked ? todayJson : null}),
    );
    expect(await api.loadToday(), isNull);
    linked = true;
    final today = await api.loadToday();
    expect(today?.record?.status, AttendanceStatus.late);
    expect(requests.map((r) => (r.method, r.path)).toSet(), {
      ('GET', '/child/school/today'),
    });
  });

  test('QR kirish: token tozalanadi, javobdagi holat o\'qiladi', () async {
    final (api, requests) = repo(
      (_) => (200, {'action': 'IN', 'today': todayJson}),
    );
    final result = await api.checkIn('  abc.def \n');
    expect(result.action, CheckInAction.arrived);
    expect(result.today?.schoolName, 'Parvoz maktabi');
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/child/school/check-in');
    expect(requests.single.data, {'token': 'abc.def'});
  });

  test('bo\'sh yoki juda uzun token — so\'rovsiz validation', () async {
    final (api, requests) = repo((_) => (200, {}));
    await expectLater(
      api.checkIn('  '),
      throwsSchool(SchoolErrorCode.validation),
    );
    await expectLater(
      api.checkIn('a' * 513),
      throwsSchool(SchoolErrorCode.validation),
    );
    expect(requests, isEmpty);
  });

  test('so\'rovnoma: holat va javoblar', () async {
    final (api, requests) = repo(
      (o) => o.method == 'GET' ? (200, careSurveyJson) : (201, {'ok': true}),
    );
    final status = await api.loadCareSurvey();
    expect(status.survey?.questions, hasLength(2));
    await api.submitCareSurvey('survey-1', {'q1': 5, 'q2': 1});
    expect(requests.last.path, '/child/school/care/survey/survey-1/responses');
    expect(requests.last.data, {
      'answers': {'q1': 5, 'q2': 1},
    });
  });

  test(
    'so\'rovnoma: noto\'g\'ri baho yoki bo\'sh javob — so\'rovsiz',
    () async {
      final (api, requests) = repo((_) => (201, {'ok': true}));
      for (final answers in [
        <String, int>{},
        {'q1': 0},
        {'q1': 6},
        {'': 3},
        {for (var i = 0; i < 13; i++) 'q$i': 3},
      ]) {
        await expectLater(
          api.submitCareSurvey('survey-1', answers),
          throwsSchool(SchoolErrorCode.validation),
        );
      }
      expect(requests, isEmpty);
    },
  );

  test('murojaatlar: ro\'yxat va yangi murojaat', () async {
    final (api, requests) = repo(
      (o) => o.method == 'GET'
          ? (200, [careRequestJson, 'buzilgan'])
          : (201, {...careRequestJson, 'id': 'req-2', 'status': 'NEW'}),
    );
    final list = await api.loadCareRequests();
    expect(list.single.id, 'req-1');

    final created = await api.createCareRequest(
      topic: CareTopic.bullying,
      message: '  Menga yordam kerak  ',
      urgency: CareUrgency.urgent,
    );
    expect(created.status, CareRequestStatus.sent);
    expect(requests.last.path, '/child/school/care/requests');
    expect(requests.last.data, {
      'topic': 'BULLYING',
      'message': 'Menga yordam kerak',
      'urgency': 'URGENT',
    });
  });

  test(
    'murojaat: noma\'lum mavzu, bo\'sh yoki uzun matn — so\'rovsiz',
    () async {
      final (api, requests) = repo((_) => (201, careRequestJson));
      await expectLater(
        api.createCareRequest(topic: CareTopic.unknown, message: 'salom'),
        throwsSchool(SchoolErrorCode.validation),
      );
      await expectLater(
        api.createCareRequest(topic: CareTopic.family, message: '   '),
        throwsSchool(SchoolErrorCode.validation),
      );
      await expectLater(
        api.createCareRequest(
          topic: CareTopic.family,
          message: 'a' * (kCareMessageMaxLength + 1),
        ),
        throwsSchool(SchoolErrorCode.validation),
      );
      expect(requests, isEmpty);
    },
  );

  test('psixologik testlar: ro\'yxat, test va javob yuborish', () async {
    final (api, requests) = repo((o) {
      if (o.method == 'POST') return (201, {'ok': true});
      if (o.path == '/child/school/assessments') {
        return (
          200,
          {
            'enrolled': true,
            'assignments': [psychSummaryJson, 42],
          },
        );
      }
      return (200, psychTestJson);
    });
    final list = await api.loadPsychAssignments();
    expect(list.single.title, 'Diqqat testi');

    final psychTest = await api.loadPsychTest('assign-1');
    expect(requests.last.path, '/child/school/assessments/assign-1');

    await api.submitPsychTest(
      psychTest,
      answers: {
        's1': const PsychSingleAnswer('a'),
        'l1': const PsychLikertAnswer(4),
        'm1': PsychMultiAnswer(['x', 'z']),
      },
      durationSec: 95,
    );
    expect(requests.last.path, '/child/school/assessments/assign-1/submit');
    expect(requests.last.data, {
      'answers': {
        's1': 'a',
        'l1': 4,
        'm1': ['x', 'z'],
      },
      'durationSec': 95,
    });
  });

  test('test javobi: mos kelmasa so\'rovsiz; vaqt chegaralanadi', () async {
    final (api, requests) = repo((_) => (201, {'ok': true}));
    final psychTest = PsychTest.tryFromJson({
      ...psychTestJson,
      'assignmentId': 'a/1',
    })!;
    await expectLater(
      api.submitPsychTest(
        psychTest,
        answers: {'l1': const PsychLikertAnswer(7)},
      ),
      throwsSchool(SchoolErrorCode.validation),
    );
    expect(requests, isEmpty);

    await api.submitPsychTest(
      psychTest,
      answers: {'l1': const PsychLikertAnswer(2)},
      durationSec: 999999,
    );
    // Id yo'l bo'lagi sifatida kodlanadi.
    expect(requests.single.path, '/child/school/assessments/a%2F1/submit');
    expect((requests.single.data as Map)['durationSec'], kMaxTestDurationSec);

    await api.submitPsychTest(
      psychTest,
      answers: {'l1': const PsychLikertAnswer(2)},
    );
    expect((requests.last.data as Map).containsKey('durationSec'), isFalse);
  });

  test('maktab topshiriqlari', () async {
    final (api, requests) = repo(
      (_) => (
        200,
        [
          schoolAssignmentJson,
          {'kind': 'TEST'},
        ],
      ),
    );
    final list = await api.loadAssignments();
    expect(list.single.kind, SchoolAssignmentKind.test);
    expect(requests.single.path, '/child/school/assignments');
  });

  test('kutilmagan javob shakli — unknown', () async {
    final (api, _) = repo((o) => (200, ['ro\'yxat obyekt o\'rniga']));
    await expectLater(api.loadToday(), throwsSchool(SchoolErrorCode.unknown));
    await expectLater(
      api.loadPsychTest('assign-1'),
      throwsSchool(SchoolErrorCode.unknown),
    );
    final (api2, _) = repo((o) => (200, {'items': []}));
    await expectLater(
      api2.loadCareRequests(),
      throwsSchool(SchoolErrorCode.unknown),
    );
  });

  group('xato kodlari', () {
    const cases = <(int, Object?, SchoolErrorCode)>[
      (400, {'code': 'KIOSK_TOKEN_INVALID'}, SchoolErrorCode.kioskInvalid),
      (400, {'code': 'KIOSK_TOKEN_EXPIRED'}, SchoolErrorCode.kioskExpired),
      (403, {'code': 'NOT_ENROLLED'}, SchoolErrorCode.notEnrolled),
      (404, {'code': 'NOT_ENROLLED'}, SchoolErrorCode.notEnrolled),
      (400, {'code': 'OUTSIDE_SCHOOL_HOURS'}, SchoolErrorCode.outsideHours),
      (404, {'code': 'SURVEY_NOT_FOUND'}, SchoolErrorCode.surveyNotFound),
      (409, {'code': 'ALREADY_ANSWERED'}, SchoolErrorCode.alreadyAnswered),
      (
        404,
        {'code': 'ASSIGNMENT_NOT_FOUND'},
        SchoolErrorCode.assignmentNotFound,
      ),
      (409, {'code': 'ALREADY_SUBMITTED'}, SchoolErrorCode.alreadySubmitted),
      (429, {'code': 'TOO_MANY_REQUESTS'}, SchoolErrorCode.tooManyRequests),
      (429, {'message': 'ThrottlerException'}, SchoolErrorCode.tooManyRequests),
      (503, {'code': 'NOT_CONFIGURED'}, SchoolErrorCode.notConfigured),
      (400, {'code': 'VALIDATION'}, SchoolErrorCode.validation),
      // Server maktab yo'llarini hali bilmaydi (Nest: "Cannot GET …").
      (
        404,
        {
          'statusCode': 404,
          'message': 'Cannot GET /api/x',
          'error': 'Not Found',
        },
        SchoolErrorCode.unavailable,
      ),
      (404, '<html>Not Found</html>', SchoolErrorCode.unavailable),
      (404, {'code': 'NOT_FOUND'}, SchoolErrorCode.unknown),
      (
        400,
        {'message': 'Validation failed (uuid is expected)'},
        SchoolErrorCode.unknown,
      ),
      (403, {'message': 'Forbidden resource'}, SchoolErrorCode.unknown),
      (500, null, SchoolErrorCode.unknown),
    ];

    for (final (status, body, expected) in cases) {
      test('$status $body → ${expected.name}', () async {
        final (api, _) = repo((_) => (status, body));
        await expectLater(api.loadToday(), throwsSchool(expected));
      });
    }

    test('VALIDATION xabari saqlanadi', () async {
      final (api, _) = repo(
        (_) => (
          400,
          {
            'statusCode': 400,
            'code': 'VALIDATION',
            'message': 'answers: errors.form.selectAtLeastOne',
          },
        ),
      );
      await expectLater(
        api.submitCareSurvey('survey-1', {'q1': 3}),
        throwsA(
          isA<SchoolException>().having(
            (e) => e.message,
            'message',
            'answers: errors.form.selectAtLeastOne',
          ),
        ),
      );
    });

    test('javob kelmasa — network', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'))
        ..httpClientAdapter = _OfflineAdapter();
      await expectLater(
        ApiSchoolRepository(dio).loadAssignments(),
        throwsSchool(SchoolErrorCode.network),
      );
    });
  });
}

class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  );

  @override
  void close({bool force = false}) {}
}
