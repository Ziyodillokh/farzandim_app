// Server manbai: yo'llar, so'rov tanasi, javob o'qilishi va xato kodlari.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/learning/data/api_learning_repository.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// So'rovlarni yozib boradigan va tayyor javob qaytaradigan adapter.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiLearningRepository, _Adapter) repo(
  (int, Object?) Function(RequestOptions) respond,
) {
  final adapter = _Adapter(respond);
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test/api',
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  )..httpClientAdapter = adapter;
  return (ApiLearningRepository(dio), adapter);
}

void main() {
  test('profil: null va saqlash', () async {
    final (api, adapter) = repo(
      (o) => o.method == 'GET'
          ? (200, {'profile': null})
          : (
              200,
              {
                'profile': {
                  'grade': 7,
                  'subjects': ['math', 'english'],
                },
              },
            ),
    );
    expect(await api.loadProfile(), isNull);
    final saved = await api.saveProfile(
      const LearningProfile(
        grade: 7,
        subjects: [Subject.math, Subject.english],
      ),
    );
    expect(saved.subjects, [Subject.math, Subject.english]);
    expect(adapter.requests.last.path, '/learning/profile');
    expect(adapter.requests.last.data, {
      'grade': 7,
      'subjects': ['math', 'english'],
    });
  });

  test('natijalar: limit va buzilgan yozuvlar o\'tkazib yuboriladi', () async {
    final (api, adapter) = repo(
      (o) => (
        200,
        {
          'items': [
            {
              'id': 'r1',
              'subject': 'math',
              'topic': null,
              'correct': 8,
              'total': 10,
              'date': '2026-10-19T10:00:00Z',
            },
            {'id': 'broken'},
          ],
          'nextBefore': null,
        },
      ),
    );
    final results = await api.loadResults(limit: 50);
    expect(results.single.id, 'r1');
    expect(adapter.requests.single.queryParameters, {'limit': 50});
  });

  test('javob yuborish va xato kodlari', () async {
    final (api, adapter) = repo((o) {
      if (o.path.endsWith('/answers')) {
        return (
          200,
          {
            'questionId': 'q1',
            'selectedIndex': 2,
            'isCorrect': true,
            'correctIndex': 2,
            'explanation': {'uz': 'a', 'ru': 'b', 'en': 'c'},
          },
        );
      }
      return (409, {'statusCode': 409, 'code': 'PROFILE_REQUIRED'});
    });
    final feedback = await api.submitAnswer(
      attemptId: 'a1',
      questionId: 'q1',
      selectedIndex: 2,
    );
    expect(feedback.isCorrect, isTrue);
    expect(adapter.requests.single.path, '/learning/attempts/a1/answers');

    await expectLater(
      api.startAttempt(Subject.math),
      throwsA(
        isA<LearningException>().having(
          (e) => e.code,
          'code',
          LearningErrorCode.profileRequired,
        ),
      ),
    );
    expect(adapter.requests.last.data, {'subject': 'math'});
  });

  test('NO_QUESTIONS va tarmoq xatosi', () async {
    final (api, _) = repo((o) => (404, {'code': 'NO_QUESTIONS'}));
    await expectLater(
      api.startAttempt(Subject.native),
      throwsA(
        isA<LearningException>().having(
          (e) => e.code,
          'code',
          LearningErrorCode.noQuestions,
        ),
      ),
    );

    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'))
      ..httpClientAdapter = _ThrowingAdapter();
    await expectLater(
      ApiLearningRepository(dio).completeAttempt('a1'),
      throwsA(
        isA<LearningException>().having(
          (e) => e.code,
          'code',
          LearningErrorCode.network,
        ),
      ),
    );
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
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
