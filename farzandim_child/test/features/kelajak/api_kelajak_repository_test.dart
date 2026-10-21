// Server manbai: metod, yo'l, so'rov tanasi (haqiqiy fixture javoblari
// bilan), noto'g'ri kirishni so'rovsiz rad etish va xato kodlari.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/kelajak/data/api_kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/network/fake_http_adapter.dart';
import 'kelajak_fixtures.dart';

(ApiKelajakRepository, List<RequestOptions>) repo(
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
  return (ApiKelajakRepository(dio), requests);
}

Matcher throwsKelajak(KelajakErrorCode code) =>
    throwsA(isA<KelajakException>().having((e) => e.code, 'code', code));

/// Xato fixture'i nomidagi HTTP status (`error_409_...` → 409).
(int, Object?) errorFixture(String name) =>
    (int.parse(name.split('_')[1]), fixture(name));

void main() {
  test('overview: GET /kelajak/overview', () async {
    final (api, requests) = repo((_) => (200, fixture('overview_ok_fresh')));
    final overview = await api.loadOverview();
    expect(overview.tests, hasLength(7));
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/kelajak/overview');
  });

  test('sessiya boshlash: POST /kelajak/sessions {type}', () async {
    final (api, requests) = repo((_) => (200, fixture('session_start_daily')));
    final session = await api.startSession(' daily ');
    expect(session.id, kDailySessionId);
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/kelajak/sessions');
    expect(requests.single.data, {'type': 'daily'});
  });

  test('bo\'sh yoki juda uzun tur — so\'rovsiz unknownType', () async {
    final (api, requests) = repo((_) => (200, {}));
    await expectLater(
      api.startSession('  '),
      throwsKelajak(KelajakErrorCode.unknownType),
    );
    await expectLater(
      api.startSession('x' * 41),
      throwsKelajak(KelajakErrorCode.unknownType),
    );
    expect(requests, isEmpty);
  });

  test('sessiyani o\'qish: GET /kelajak/sessions/:id', () async {
    final (api, requests) = repo(
      (_) => (200, fixture('session_daily_in_progress')),
    );
    final session = await api.loadSession(kDailySessionId);
    expect(session.answers, hasLength(3));
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/kelajak/sessions/$kDailySessionId');
  });

  test('javob: PUT shkala qiymati', () async {
    final (api, requests) = repo((_) => (200, fixture('answer_put_scale')));
    final ack = await api.saveAnswer(
      sessionId: kDailySessionId,
      questionId: kDailyFirstQuestion,
      value: 1,
    );
    expect(ack.value, 1);
    expect(ack.sessionStatus, KelajakSessionStatus.inProgress);
    expect(requests.single.method, 'PUT');
    expect(
      requests.single.path,
      '/kelajak/sessions/$kDailySessionId/answers/$kDailyFirstQuestion',
    );
    expect(requests.single.data, {'value': 1});
  });

  test('javob: ochiq matn (bo\'shliqsiz) va o\'chirish ("")', () async {
    var cleared = false;
    final (api, requests) = repo(
      (_) => (
        200,
        fixture(cleared ? 'answer_put_text_cleared' : 'answer_put_text'),
      ),
    );
    final saved = await api.saveAnswer(
      sessionId: kVoiceSessionId,
      questionId: kVoiceFirstQuestion,
      text: '  Robot yasash va rasm chizish menga juda yoqadi \n',
    );
    expect(saved.answer?.text, startsWith('Robot'));
    expect(requests.last.data, {
      'text': 'Robot yasash va rasm chizish menga juda yoqadi',
    });

    cleared = true;
    final removed = await api.saveAnswer(
      sessionId: kVoiceSessionId,
      questionId: kVoiceFirstQuestion,
      text: '   ',
    );
    expect(removed.isCleared, isTrue);
    expect(requests.last.data, {'text': ''});
    expect(requests.map((r) => r.method).toSet(), {'PUT'});
  });

  test('javob: noto\'g\'ri kirish — so\'rovsiz invalidAnswer', () async {
    final (api, requests) = repo((_) => (200, fixture('answer_put_scale')));
    await expectLater(
      api.saveAnswer(sessionId: 's', questionId: 'q'),
      throwsKelajak(KelajakErrorCode.invalidAnswer),
    );
    await expectLater(
      api.saveAnswer(sessionId: 's', questionId: 'q', value: 1, text: 'a'),
      throwsKelajak(KelajakErrorCode.invalidAnswer),
    );
    await expectLater(
      api.saveAnswer(sessionId: 's', questionId: 'q', text: 'a' * 1001),
      throwsKelajak(KelajakErrorCode.invalidAnswer),
    );
    await expectLater(
      api.saveAnswer(sessionId: 's', questionId: ' ', value: 1),
      throwsKelajak(KelajakErrorCode.questionNotInSession),
    );
    await expectLater(
      api.saveAnswer(sessionId: '', questionId: 'q', value: 1),
      throwsKelajak(KelajakErrorCode.sessionNotFound),
    );
    expect(requests, isEmpty);
  });

  test('yakunlash: POST /kelajak/sessions/:id/complete (tanasiz)', () async {
    final (api, requests) = repo(
      (_) => (200, fixture('session_complete_daily')),
    );
    final session = await api.completeSession(kDailySessionId);
    expect(session.isCompleted, isTrue);
    expect(session.result?.answered, 10);
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/kelajak/sessions/$kDailySessionId/complete');
    expect(requests.single.data, isNull);
  });

  test('rivojlanish: GET /kelajak/progress', () async {
    final (api, requests) = repo((_) => (200, fixture('progress_multi_day')));
    final progress = await api.loadProgress();
    expect(progress.sessionsCompleted, 7);
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/kelajak/progress');
  });

  test('natijalar: limit va kursor', () async {
    final (api, requests) = repo(
      (o) => (
        200,
        fixture(
          o.queryParameters.containsKey('before')
              ? 'results_page2_limit2'
              : 'results_page1_limit2',
        ),
      ),
    );
    final first = await api.loadResults(limit: 2);
    expect(first.items, hasLength(2));
    expect(requests.last.method, 'GET');
    expect(requests.last.path, '/kelajak/results');
    expect(requests.last.queryParameters, {'limit': 2});

    final second = await api.loadResults(before: first.nextBefore, limit: 2);
    expect(
      second.items.map((s) => s.id),
      isNot(contains(first.items.first.id)),
    );
    expect(requests.last.queryParameters, {
      'limit': 2,
      'before': '2026-10-21T04:05:52.075Z',
    });

    await api.loadResults(limit: 500);
    expect(requests.last.queryParameters, {'limit': 100});
  });

  group('xato kodlari', () {
    const expected = {
      'error_409_age_required': KelajakErrorCode.ageRequired,
      'error_409_age_out_of_range': KelajakErrorCode.ageOutOfRange,
      'error_400_unknown_type': KelajakErrorCode.unknownType,
      'error_409_session_closed': KelajakErrorCode.sessionClosed,
      'error_400_unanswered': KelajakErrorCode.unanswered,
      'error_400_invalid_answer': KelajakErrorCode.invalidAnswer,
      'error_400_question_not_in_session':
          KelajakErrorCode.questionNotInSession,
      'error_404_session_not_found': KelajakErrorCode.sessionNotFound,
    };

    test('har xato fixture\'i o\'z kodiga', () async {
      for (final MapEntry(key: name, value: code) in expected.entries) {
        final (api, _) = repo((_) => errorFixture(name));
        await expectLater(
          api.startSession('daily'),
          throwsKelajak(code),
          reason: name,
        );
      }
    });

    test('UNANSWERED — javobsiz majburiy savollar ro\'yxati', () async {
      final (api, _) = repo((_) => errorFixture('error_400_unanswered'));
      KelajakException? error;
      try {
        await api.completeSession(kDailySessionId);
      } on KelajakException catch (e) {
        error = e;
      }
      expect(error?.code, KelajakErrorCode.unanswered);
      expect(error?.remaining, hasLength(7));
      expect(error?.message, 'Not all required questions are answered');
    });

    test('kontraktdagi qolgan kodlar', () async {
      final cases = <(int, Object?, KelajakErrorCode)>[
        (404, {'code': 'NO_QUESTIONS'}, KelajakErrorCode.noQuestions),
        (503, {'code': 'NOT_CONFIGURED'}, KelajakErrorCode.notConfigured),
        // Eski server: Kelajak yo'llari yo'q — Nest kodsiz 404.
        (
          404,
          {'message': 'Cannot GET /api/kelajak'},
          KelajakErrorCode.unavailable,
        ),
        (500, {'message': 'Internal'}, KelajakErrorCode.unknown),
        (
          400,
          {
            'message': ['type must be a string'],
          },
          KelajakErrorCode.unknown,
        ),
      ];
      for (final (status, body, code) in cases) {
        final (api, _) = repo((_) => (status, body));
        await expectLater(api.loadOverview(), throwsKelajak(code));
      }
    });

    test('noto\'g\'ri javob formati — unknown', () async {
      final (api, _) = repo((_) => (200, ['not', 'an', 'object']));
      await expectLater(
        api.loadOverview(),
        throwsKelajak(KelajakErrorCode.unknown),
      );
      final (broken, _) = repo((_) => (200, {'id': kDailySessionId}));
      await expectLater(
        broken.startSession('daily'),
        throwsKelajak(KelajakErrorCode.unknown),
      );
    });

    test('tarmoq xatosi — network', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'))
        ..httpClientAdapter = _OfflineAdapter();
      await expectLater(
        ApiKelajakRepository(dio).loadProgress(),
        throwsKelajak(KelajakErrorCode.network),
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
