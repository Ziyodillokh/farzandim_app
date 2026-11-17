// CredentialsFailure: backend `{statusCode, code, message}` xatolarini turga
// va i18n kalitga o'girish. Muhimi: 409 LOGIN_TAKEN alohida tur, 404 `code`siz
// — "bo`lim yo`q" (backend hali deploy qilinmagan), `code`li 404 esa "bola
// topilmadi"; xato matni parolni ham, tanani ham chiqarmaydi.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:flutter_test/flutter_test.dart';

final _request = RequestOptions(path: '/children/kid-1/credentials');

DioException _http(int status, [Object? body]) => DioException(
  requestOptions: _request,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: _request,
    statusCode: status,
    data: body,
  ),
);

CredentialsFailureKind _kindOf(int status, [Object? body]) =>
    CredentialsFailure.fromError(_http(status, body)).kind;

Map<String, Object> _body(int status, String code) => {
  'statusCode': status,
  'code': code,
  'message': 'sabab',
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
  group('backend `code` va status', () {
    test('409 LOGIN_TAKEN → loginTaken', () {
      final failure = CredentialsFailure.fromError(
        _http(409, _body(409, 'LOGIN_TAKEN')),
      );
      expect(failure.kind, CredentialsFailureKind.loginTaken);
      expect(failure.code, 'LOGIN_TAKEN');
      expect(failure.statusCode, 409);
    });

    test('409 `code`siz ham login bandligi (bu bo`limda boshqa 409 yo`q)', () {
      expect(_kindOf(409), CredentialsFailureKind.loginTaken);
      expect(
        _kindOf(409, const {'statusCode': 409, 'message': 'Conflict'}),
        CredentialsFailureKind.loginTaken,
      );
    });

    test('so`rov yo`q yoki allaqachon hal qilingan → requestGone', () {
      expect(
        _kindOf(404, _body(404, 'REQUEST_NOT_FOUND')),
        CredentialsFailureKind.requestGone,
      );
      expect(
        _kindOf(409, _body(409, 'ALREADY_RESOLVED')),
        CredentialsFailureKind.requestGone,
      );
    });

    test('boshqa `code`li 409 — noma`lum', () {
      expect(
        _kindOf(409, _body(409, 'SOMETHING_NEW')),
        CredentialsFailureKind.unknown,
      );
    });

    test('status bo`yicha turlar', () {
      expect(
        _kindOf(400, _body(400, 'VALIDATION')),
        CredentialsFailureKind.validation,
      );
      expect(_kindOf(422), CredentialsFailureKind.validation);
      expect(_kindOf(401), CredentialsFailureKind.sessionExpired);
      expect(
        _kindOf(403, _body(403, 'FORBIDDEN')),
        CredentialsFailureKind.forbidden,
      );
      expect(_kindOf(429), CredentialsFailureKind.tooManyAttempts);
      expect(_kindOf(500), CredentialsFailureKind.server);
      expect(_kindOf(503), CredentialsFailureKind.server);
      expect(_kindOf(418), CredentialsFailureKind.unknown);
    });

    test('404: `code`siz — bo`lim yo`q, `code`li — bola topilmadi', () {
      final missing = CredentialsFailure.fromError(
        _http(404, const {
          'statusCode': 404,
          'message': 'Cannot GET /api/children/kid-1/credentials',
          'error': 'Not Found',
        }),
      );
      expect(missing.kind, CredentialsFailureKind.unavailable);
      expect(missing.isUnavailable, isTrue);

      final child = CredentialsFailure.fromError(
        _http(404, _body(404, 'NOT_FOUND')),
      );
      expect(child.kind, CredentialsFailureKind.notFound);
      expect(child.isUnavailable, isFalse);
    });

    test('javob yo`q — network; bekor qilingan so`rov — unknown', () {
      final offline = DioException.connectionError(
        requestOptions: _request,
        reason: 'offline',
      );
      expect(
        CredentialsFailure.fromError(offline).kind,
        CredentialsFailureKind.network,
      );
      final cancelled = DioException.requestCancelled(
        requestOptions: _request,
        reason: 'bekor',
      );
      expect(
        CredentialsFailure.fromError(cancelled).kind,
        CredentialsFailureKind.unknown,
      );
    });

    test('Dio xatosi bo`lmagan xato — unknown; o`zi o`zgarishsiz o`tadi', () {
      expect(
        CredentialsFailure.fromError(StateError('x')).kind,
        CredentialsFailureKind.unknown,
      );
      const original = CredentialsFailure(CredentialsFailureKind.malformed);
      expect(CredentialsFailure.fromError(original), same(original));
    });
  });

  test('toString faqat tur, kod va status (tana yo`q)', () {
    final failure = CredentialsFailure.fromError(
      _http(409, {
        ..._body(409, 'LOGIN_TAKEN'),
        'temporaryPassword': 'sir1234',
      }),
    );
    final text = failure.toString();
    expect(text, contains('loginTaken'));
    expect(text, contains('409'));
    expect(text, isNot(contains('sir1234')));
  });

  test('tenglik qiymat bo`yicha', () {
    expect(
      const CredentialsFailure(CredentialsFailureKind.server, statusCode: 500),
      const CredentialsFailure(CredentialsFailureKind.server, statusCode: 500),
    );
    expect(
      const CredentialsFailure(CredentialsFailureKind.server),
      isNot(const CredentialsFailure(CredentialsFailureKind.network)),
    );
  });

  group('guardCredentialsCall', () {
    test('DioException → CredentialsFailure', () async {
      await expectLater(
        guardCredentialsCall<void>('test', () async => throw _http(429)),
        throwsA(
          isA<CredentialsFailure>().having(
            (f) => f.kind,
            'kind',
            CredentialsFailureKind.tooManyAttempts,
          ),
        ),
      );
    });

    test('ichki CredentialsFailure va boshqa xatolar o`zgarishsiz', () async {
      const inner = CredentialsFailure(CredentialsFailureKind.validation);
      await expectLater(
        guardCredentialsCall<void>('test', () async => throw inner),
        throwsA(inner),
      );
      await expectLater(
        guardCredentialsCall<void>('test', () async => throw StateError('x')),
        throwsStateError,
      );
    });

    test('muvaffaqiyatda qiymat qaytadi', () async {
      expect(await guardCredentialsCall('test', () async => 7), 7);
    });
  });

  group('xabar kalitlari uz/ru/en da bor', () {
    final langs = <String, Map<String, dynamic>>{
      for (final lang in ['uz', 'ru', 'en'])
        lang:
            jsonDecode(
                  File('assets/translations/$lang.json').readAsStringSync(),
                )
                as Map<String, dynamic>,
    };

    test('har tur uchun bo`sh bo`lmagan tarjima', () {
      for (final kind in CredentialsFailureKind.values) {
        final key = CredentialsFailure(kind).messageKey;
        for (final entry in langs.entries) {
          final value = _lookup(entry.value, key);
          expect(value, isA<String>(), reason: '${entry.key}: $key');
          expect((value! as String).trim(), isNotEmpty, reason: key);
        }
      }
    });
  });
}
