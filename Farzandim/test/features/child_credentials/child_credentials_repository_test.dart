// ChildCredentialsRepository: yo'l, metod va tana; `null`/bo'sh javob —
// "berilmagan"; login so'rovdan oldin tekshiriladi; parol faqat qaytariladi;
// xatolar CredentialsFailure'ga aylanadi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/child_credentials/data/child_credentials_repository.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

Matcher _failure(CredentialsFailureKind kind) =>
    throwsA(isA<CredentialsFailure>().having((f) => f.kind, 'kind', kind));

const _issued = {
  'login': 'aziza.k24',
  'temporaryPassword': 'k7m2xq9p',
  'issuedAt': '2026-11-06T08:30:00.000Z',
};

void main() {
  late FakeHttpAdapter adapter;
  late ChildCredentialsRepository repo;
  var reply = const FakeReply(200);

  setUp(() {
    reply = const FakeReply(200);
    adapter = FakeHttpAdapter((_) => reply);
    repo = ChildCredentialsRepository(dio: fakeDio(adapter));
  });

  RequestOptions last() => adapter.requests.last;

  group('GET /credentials', () {
    test('berilgan: login, kim bergan, birinchi kirish', () async {
      reply = const FakeReply(200, {
        'login': 'aziza.k24',
        'issuedBy': 'PARENT',
        'issuedAt': '2026-11-06T08:30:00.000Z',
        'mustChangePassword': true,
        'lastLoginAt': null,
      });
      final credentials = await repo.fetchCredentials('kid-1');
      expect(last().method, 'GET');
      expect(last().path, '/children/kid-1/credentials');
      expect(credentials!.login, 'aziza.k24');
      expect(credentials.isFirstLoginPending, isTrue);
    });

    test('berilmagan: bo`sh tana ham, JSON null ham → null', () async {
      reply = const FakeReply(200);
      expect(await repo.fetchCredentials('kid-1'), isNull);
      reply = const FakeReply(200, 'null');
      expect(await repo.fetchCredentials('kid-1'), isNull);
    });

    test('bola id yo`l bo`lagiga kodlanadi, bo`sh id so`rovsiz rad', () async {
      reply = const FakeReply(200);
      await repo.fetchCredentials('a/b c');
      expect(last().path, '/children/a%2Fb%20c/credentials');

      final count = adapter.requests.length;
      await expectLater(
        repo.fetchCredentials(' '),
        _failure(CredentialsFailureKind.validation),
      );
      expect(adapter.requests, hasLength(count));
    });
  });

  group('POST /credentials — birinchi berish', () {
    test('loginsiz: signOutDevices=false, parol qaytadi', () async {
      reply = const FakeReply(201, _issued);
      final issued = await repo.issueCredentials('kid-1');
      expect(last().method, 'POST');
      expect(last().path, '/children/kid-1/credentials');
      // Aniq `false`: eskirgan ekran "berish"ni yuborsa ham backend uni
      // "yangilash" deb qabul qilib, ulangan telefonni chiqarib yubormasin.
      expect(last().data, {'signOutDevices': false});
      expect(issued.login, 'aziza.k24');
      expect(issued.temporaryPassword, 'k7m2xq9p');
    });

    test('o`z logini: kichik harfga o`tkazilib yuboriladi', () async {
      reply = const FakeReply(201, _issued);
      await repo.issueCredentials('kid-1', login: '  Aziza.K24 ');
      expect(last().data, {'login': 'aziza.k24', 'signOutDevices': false});
    });

    test('bo`sh login yuborilmaydi', () async {
      reply = const FakeReply(201, _issued);
      await repo.issueCredentials('kid-1', login: '   ');
      expect(last().data, {'signOutDevices': false});
    });

    test('yaroqsiz login tarmoqqa chiqmaydi', () async {
      for (final login in ['ab', '1abcd', 'ab cd', 'a' * 25]) {
        await expectLater(
          repo.issueCredentials('kid-1', login: login),
          _failure(CredentialsFailureKind.validation),
          reason: login,
        );
      }
      expect(adapter.requests, isEmpty);
    });

    test('409 LOGIN_TAKEN → loginTaken', () async {
      reply = const FakeReply(409, {
        'statusCode': 409,
        'code': 'LOGIN_TAKEN',
        'message': 'Login is taken',
      });
      await expectLater(
        repo.issueCredentials('kid-1', login: 'aziza.k24'),
        _failure(CredentialsFailureKind.loginTaken),
      );
    });

    test('parolsiz muvaffaqiyatli javob → malformed', () async {
      reply = const FakeReply(201, {'login': 'aziza.k24'});
      await expectLater(
        repo.issueCredentials('kid-1'),
        _failure(CredentialsFailureKind.malformed),
      );
      reply = const FakeReply(201);
      await expectLater(
        repo.issueCredentials('kid-1'),
        _failure(CredentialsFailureKind.malformed),
      );
    });
  });

  group('POST /credentials — yangilash', () {
    test('signOutDevices aniq yuboriladi (yoqilgan)', () async {
      reply = const FakeReply(201, _issued);
      final issued = await repo.resetCredentials('kid-1', signOutDevices: true);
      expect(last().method, 'POST');
      expect(last().path, '/children/kid-1/credentials');
      expect(last().data, {'signOutDevices': true});
      expect(issued.temporaryPassword, 'k7m2xq9p');
    });

    test('signOutDevices o`chirilgan', () async {
      reply = const FakeReply(201, _issued);
      await repo.resetCredentials('kid-1', signOutDevices: false);
      expect(last().data, {'signOutDevices': false});
    });

    test('xatolar: 403, 404 (bola), 429, tarmoq', () async {
      reply = const FakeReply(403, {'statusCode': 403, 'code': 'FORBIDDEN'});
      await expectLater(
        repo.resetCredentials('kid-1', signOutDevices: true),
        _failure(CredentialsFailureKind.forbidden),
      );
      reply = const FakeReply(404, {'statusCode': 404, 'code': 'NOT_FOUND'});
      await expectLater(
        repo.resetCredentials('kid-1', signOutDevices: true),
        _failure(CredentialsFailureKind.notFound),
      );
      reply = const FakeReply(429, {'statusCode': 429, 'message': 'Throttled'});
      await expectLater(
        repo.resetCredentials('kid-1', signOutDevices: true),
        _failure(CredentialsFailureKind.tooManyAttempts),
      );
      reply = const FakeReply.offline();
      await expectLater(
        repo.resetCredentials('kid-1', signOutDevices: true),
        _failure(CredentialsFailureKind.network),
      );
    });
  });

  group('recovery-requests', () {
    test('GET — massiv shakli', () async {
      reply = const FakeReply(200, [
        {
          'id': 'r-1',
          'channel': 'PARENT',
          'status': 'RECEIVED',
          'createdAt': '2026-11-06T08:00:00.000Z',
        },
      ]);
      final requests = await repo.fetchRecoveryRequests('kid-1');
      expect(last().method, 'GET');
      expect(last().path, '/children/kid-1/recovery-requests');
      expect(requests.single.id, 'r-1');
      expect(requests.single.isOpen, isTrue);
    });

    test('GET — `requests` obyekti ichida va bo`sh', () async {
      reply = const FakeReply(200, {
        'requests': [
          {'id': 'r-2', 'channel': 'SCHOOL', 'status': 'RECEIVED'},
        ],
      });
      expect((await repo.fetchRecoveryRequests('kid-1')).single.id, 'r-2');
      reply = const FakeReply(200, []);
      expect(await repo.fetchRecoveryRequests('kid-1'), isEmpty);
      reply = const FakeReply(200);
      expect(await repo.fetchRecoveryRequests('kid-1'), isEmpty);
    });

    test('POST /:id/reject — bo`sh JSON tana bilan', () async {
      reply = const FakeReply(204);
      await repo.rejectRecoveryRequest('kid-1', 'r-1');
      expect(last().method, 'POST');
      expect(last().path, '/children/kid-1/recovery-requests/r-1/reject');
      expect(last().data, <String, dynamic>{});
    });

    test('reject: so`rov id yo`l bo`lagiga kodlanadi, bo`sh id rad', () async {
      reply = const FakeReply(204);
      await repo.rejectRecoveryRequest('kid-1', 'a/b');
      expect(last().path, '/children/kid-1/recovery-requests/a%2Fb/reject');
      final count = adapter.requests.length;
      await expectLater(
        repo.rejectRecoveryRequest('kid-1', ''),
        _failure(CredentialsFailureKind.validation),
      );
      expect(adapter.requests, hasLength(count));
    });

    test('reject: allaqachon hal bo`lgan so`rov → requestGone', () async {
      reply = const FakeReply(409, {
        'statusCode': 409,
        'code': 'ALREADY_RESOLVED',
        'message': 'Recovery request is already resolved',
      });
      await expectLater(
        repo.rejectRecoveryRequest('kid-1', 'r-1'),
        _failure(CredentialsFailureKind.requestGone),
      );
      reply = const FakeReply(404, {
        'statusCode': 404,
        'code': 'REQUEST_NOT_FOUND',
        'message': 'Recovery request not found',
      });
      await expectLater(
        repo.rejectRecoveryRequest('kid-1', 'r-1'),
        _failure(CredentialsFailureKind.requestGone),
      );
    });

    test('backend deploy qilinmagan (404 code`siz) → unavailable', () async {
      reply = const FakeReply(404, {
        'statusCode': 404,
        'message': 'Cannot GET /api/children/kid-1/recovery-requests',
        'error': 'Not Found',
      });
      await expectLater(
        repo.fetchRecoveryRequests('kid-1'),
        _failure(CredentialsFailureKind.unavailable),
      );
    });
  });

  test('ChildCredentials turi qaytadi (null emas) — berilgan bola', () async {
    reply = const FakeReply(200, {'login': 'aziza.k24', 'issuedBy': 'SCHOOL'});
    expect(await repo.fetchCredentials('kid-1'), isA<ChildCredentials>());
  });
}
