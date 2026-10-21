// SchoolFailure: backend `{statusCode, code, message}` xatolarini turga va
// i18n kalitga o'girish. Eng muhimi: 404 `code`siz — "bo'lim mavjud emas"
// (backend hali deploy qilinmagan), `code`li 404 esa oddiy "topilmadi".

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_test/flutter_test.dart';

final _request = RequestOptions(path: '/parent/school/link');

DioException _http(int status, [Object? body]) => DioException(
  requestOptions: _request,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: _request,
    statusCode: status,
    data: body,
  ),
);

SchoolFailureKind _kindOf(int status, [Object? body]) =>
    SchoolFailure.fromError(_http(status, body)).kind;

Map<String, Object> _school(int status, String code, [String message = '']) => {
  'statusCode': status,
  'code': code,
  'message': message,
};

Object? _lookup(Map<String, dynamic> root, String dottedKey) {
  Object? node = root;
  for (final part in dottedKey.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node;
}

void main() {
  group('backend `code` birma-bir', () {
    final cases = <String, (int, SchoolFailureKind)>{
      'VALIDATION': (400, SchoolFailureKind.validation),
      'INVITE_INVALID': (404, SchoolFailureKind.inviteInvalid),
      'TOO_MANY_ATTEMPTS': (429, SchoolFailureKind.tooManyAttempts),
      'STUDENT_NOT_FOUND': (404, SchoolFailureKind.studentNotFound),
      'CHILD_NOT_FOUND': (404, SchoolFailureKind.childNotFound),
      'STUDENT_LINKED_ELSEWHERE': (
        409,
        SchoolFailureKind.studentLinkedElsewhere,
      ),
      'LINK_NOT_FOUND': (404, SchoolFailureKind.linkNotFound),
      'NOT_FOUND': (404, SchoolFailureKind.notFound),
      'CONFLICT': (409, SchoolFailureKind.conflict),
      'FORBIDDEN': (403, SchoolFailureKind.forbidden),
    };
    for (final MapEntry(key: code, value: (status, kind)) in cases.entries) {
      test('$code → ${kind.name}', () {
        final failure = SchoolFailure.fromError(
          _http(status, _school(status, code, 'reason')),
        );
        expect(failure.kind, kind);
        expect(failure.code, code);
        expect(failure.statusCode, status);
        expect(failure.detail, 'reason');
      });
    }

    test('VALIDATION: taklif kodi formati alohida tur', () {
      expect(
        _kindOf(
          400,
          _school(400, 'VALIDATION', 'code: errors.school.inviteCodeFormat'),
        ),
        SchoolFailureKind.inviteFormat,
      );
      expect(
        _kindOf(
          400,
          _school(400, 'VALIDATION', 'time: errors.form.invalidTime'),
        ),
        SchoolFailureKind.validation,
      );
    });

    test('CONFLICT: erta ketish va to`lov so`rovi sabablari ajratiladi', () {
      expect(
        _kindOf(409, _school(409, 'CONFLICT', 'pending')),
        SchoolFailureKind.earlyExitPending,
      );
      expect(
        _kindOf(409, _school(409, 'CONFLICT', 'open verification exists')),
        SchoolFailureKind.verificationOpen,
      );
    });

    test('noma`lum `code` — status bo`yicha (404 → notFound)', () {
      expect(
        _kindOf(404, _school(404, 'SOMETHING_NEW')),
        SchoolFailureKind.notFound,
      );
      expect(
        _kindOf(409, _school(409, 'SOMETHING_NEW')),
        SchoolFailureKind.conflict,
      );
    });
  });

  group('404 `code`siz → unavailable (bo`lim yo`q)', () {
    test('Nest marshrut topilmadi javobi', () {
      final failure = SchoolFailure.fromError(
        _http(404, {
          'statusCode': 404,
          'message': 'Cannot GET /api/parent/school/links',
          'error': 'Not Found',
        }),
      );
      expect(failure.kind, SchoolFailureKind.unavailable);
      expect(failure.isUnavailable, isTrue);
    });

    test('HTML yoki bo`sh tana ham', () {
      expect(_kindOf(404, '<html>404</html>'), SchoolFailureKind.unavailable);
      expect(_kindOf(404), SchoolFailureKind.unavailable);
    });

    test('Growth: "Child not found" (code yo`q) ham', () {
      expect(
        _kindOf(404, {'statusCode': 404, 'message': 'Child not found'}),
        SchoolFailureKind.unavailable,
      );
    });
  });

  group('status bo`yicha', () {
    test('429 throttler (code yo`q) → tooManyAttempts', () {
      expect(
        _kindOf(429, {
          'statusCode': 429,
          'message': 'ThrottlerException: Too Many Requests',
        }),
        SchoolFailureKind.tooManyAttempts,
      );
    });

    test('400 ParseUUIDPipe va class-validator ro`yxati → validation', () {
      expect(
        _kindOf(400, {
          'statusCode': 400,
          'message': 'Validation failed (uuid is expected)',
        }),
        SchoolFailureKind.validation,
      );
      final failure = SchoolFailure.fromError(
        _http(400, {
          'statusCode': 400,
          'message': ['days must be one of: 7, 30'],
        }),
      );
      expect(failure.kind, SchoolFailureKind.validation);
      expect(failure.detail, 'days must be one of: 7, 30');
    });

    test('401, 403 (bola tokeni), 5xx va boshqalar', () {
      expect(_kindOf(401), SchoolFailureKind.sessionExpired);
      expect(
        _kindOf(403, {
          'statusCode': 403,
          'message': 'Forbidden resource',
          'error': 'Forbidden',
        }),
        SchoolFailureKind.forbidden,
      );
      expect(_kindOf(500), SchoolFailureKind.server);
      expect(
        _kindOf(502, '<html>Bad Gateway</html>'),
        SchoolFailureKind.server,
      );
      expect(_kindOf(418), SchoolFailureKind.unknown);
    });
  });

  group('javob yo`q va boshqa xatolar', () {
    test('ulanish / timeout → network', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.unknown,
      ]) {
        final failure = SchoolFailure.fromError(
          DioException(requestOptions: _request, type: type),
        );
        expect(failure.kind, SchoolFailureKind.network, reason: type.name);
      }
    });

    test('bekor qilingan so`rov → unknown', () {
      expect(
        SchoolFailure.fromError(
          DioException(requestOptions: _request, type: DioExceptionType.cancel),
        ).kind,
        SchoolFailureKind.unknown,
      );
    });

    test('Dio bo`lmagan xato → unknown; SchoolFailure o`zgarmaydi', () {
      expect(
        SchoolFailure.fromError(const FormatException('x')).kind,
        SchoolFailureKind.unknown,
      );
      const original = SchoolFailure(SchoolFailureKind.inviteFormat);
      expect(SchoolFailure.fromError(original), same(original));
    });
  });

  group('shouldRefresh', () {
    test('eskirgan ro`yxat turlari — true, tarmoq va format — false', () {
      expect(
        const SchoolFailure(SchoolFailureKind.linkNotFound).shouldRefresh,
        isTrue,
      );
      expect(
        const SchoolFailure(
          SchoolFailureKind.studentLinkedElsewhere,
        ).shouldRefresh,
        isTrue,
      );
      expect(
        const SchoolFailure(SchoolFailureKind.unavailable).shouldRefresh,
        isTrue,
      );
      expect(
        const SchoolFailure(SchoolFailureKind.network).shouldRefresh,
        isFalse,
      );
      expect(
        const SchoolFailure(SchoolFailureKind.inviteInvalid).shouldRefresh,
        isFalse,
      );
    });
  });

  group('guardSchoolCall', () {
    test('DioException SchoolFailure`ga aylanadi', () async {
      await expectLater(
        guardSchoolCall<void>('t', () async => throw _http(404)),
        throwsA(
          isA<SchoolFailure>().having(
            (f) => f.kind,
            'kind',
            SchoolFailureKind.unavailable,
          ),
        ),
      );
    });

    test('natija va ichki SchoolFailure o`zgarishsiz o`tadi', () async {
      expect(await guardSchoolCall('t', () async => 42), 42);
      await expectLater(
        guardSchoolCall<void>(
          't',
          () async => throw const SchoolFailure(SchoolFailureKind.inviteFormat),
        ),
        throwsA(const SchoolFailure(SchoolFailureKind.inviteFormat)),
      );
    });
  });

  test('har bir turning xabar kaliti uz/ru/en tarjimalarida bor', () {
    final langs = {
      for (final lang in ['uz', 'ru', 'en'])
        lang:
            jsonDecode(
                  File('assets/translations/$lang.json').readAsStringSync(),
                )
                as Map<String, dynamic>,
    };
    for (final kind in SchoolFailureKind.values) {
      final key = SchoolFailure(kind).messageKey;
      for (final MapEntry(key: lang, value: root) in langs.entries) {
        final value = _lookup(root, key);
        expect(value, isA<String>(), reason: '$lang: $key yo`q');
        expect((value! as String).trim(), isNotEmpty, reason: '$lang: $key');
      }
    }
  });
}
