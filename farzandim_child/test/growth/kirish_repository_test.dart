// Kirish server manbai: yo'llar, so'rov tanasi, javob o'qilishi va xato
// kodlari (K1 `docs/KIRISH-AUTH-API.md`, K2 `docs/KIRISH-SCHOOL-API.md`).

import 'package:dio/dio.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/network/fake_http_adapter.dart';
import 'fake_kirish.dart';

(ApiKirishRepository, List<RequestOptions>) _repo(
  (int, Object?) Function(RequestOptions options) respond,
) {
  final requests = <RequestOptions>[];
  Dio dio() =>
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
  return (ApiKirishRepository(authed: dio(), public: dio()), requests);
}

Matcher _throwsKirish(
  KirishError error, {
  Duration? retryAfter,
  PasswordIssue? passwordIssue,
}) => throwsA(
  isA<KirishException>()
      .having((e) => e.error, 'error', error)
      .having((e) => e.retryAfter, 'retryAfter', retryAfter)
      .having((e) => e.passwordIssue, 'passwordIssue', passwordIssue),
);

void main() {
  group('kirish', () {
    test('OK — sessiya, qurilma roli; login kichik harfda', () async {
      final (api, requests) = _repo(
        (_) => (
          200,
          {
            'status': 'OK',
            'accessToken': 'a',
            'refreshToken': 'r',
            'sessionId': 's1',
            'deviceRole': 'SECONDARY',
            'child': {'id': 'c1', 'name': 'Aziza Karimova'},
            'user': {'id': 'u1'},
          },
        ),
      );
      final result = await api.login(
        login: ' Aziza.K24 ',
        password: 'parol1234',
        device: kTestDevice,
      );
      final session = (result as LoginOk).session;
      expect(session.childId, 'c1');
      expect(session.sessionId, 's1');
      expect(session.role, DeviceRole.secondary);
      expect(requests.single.path, '/auth/child-login');
      expect(requests.single.data, {
        'login': 'aziza.k24',
        'password': 'parol1234',
        'device': {
          'id': 'install-1',
          'platform': 'android',
          'model': 'Galaxy A15',
        },
      });
    });

    test('vaqtinchalik parol — sozlash tokeni', () async {
      final (api, _) = _repo(
        (_) => (
          200,
          {
            'status': 'SETUP_REQUIRED',
            'setupToken': 'jwt',
            'child': {'id': 'c1', 'name': 'Aziza'},
          },
        ),
      );
      final result = await api.login(
        login: 'aziza.k24',
        password: 'k7m2qx9d',
        device: kTestDevice,
      );
      expect((result as LoginNeedsSetup).setupToken, 'jwt');
      expect(result.childName, 'Aziza');
    });

    test('xatolar: 401, LOCKED, IP limiti, tarmoq', () async {
      Future<void> call(ApiKirishRepository api) =>
          api.login(login: 'a.b1', password: 'x', device: kTestDevice);
      await expectLater(
        call(_repo((_) => (401, {'code': 'INVALID_CREDENTIALS'})).$1),
        _throwsKirish(KirishError.invalidCredentials),
      );
      // Vaqtinchalik parol to'g'ri, lekin 14 kunlik muddati o'tgan.
      await expectLater(
        call(_repo((_) => (401, {'code': 'TEMP_PASSWORD_EXPIRED'})).$1),
        _throwsKirish(KirishError.tempExpired),
      );
      await expectLater(
        call(
          _repo((_) => (429, {'code': 'LOCKED', 'retryAfterSeconds': 900})).$1,
        ),
        _throwsKirish(
          KirishError.locked,
          retryAfter: const Duration(minutes: 15),
        ),
      );
      await expectLater(
        call(
          _repo(
            (_) => (429, {'code': 'RATE_LIMITED', 'retryAfterSeconds': 60}),
          ).$1,
        ),
        _throwsKirish(
          KirishError.rateLimited,
          retryAfter: const Duration(minutes: 1),
        ),
      );
      final offline = ApiKirishRepository(
        authed: Dio(),
        public: Dio()
          ..httpClientAdapter = FakeHttpAdapter(
            (o) => throw DioException.connectionError(
              requestOptions: o,
              reason: 'offline',
            ),
          ),
      );
      await expectLater(call(offline), _throwsKirish(KirishError.network));
    });

    test(
      'sozlash: 401 — token eskirgan, 400 WEAK_PASSWORD — sababi bilan',
      () async {
        Future<void> call(ApiKirishRepository api) => api.completeSetup(
          setupToken: 't',
          newPassword: 'Kitob2026',
          device: kTestDevice,
        );
        await expectLater(
          call(_repo((_) => (401, {'code': 'SETUP_TOKEN_INVALID'})).$1),
          _throwsKirish(KirishError.setupExpired),
        );
        for (final (reason, issue) in const [
          ('TOO_COMMON', PasswordIssue.tooCommon),
          ('SAME_AS_CURRENT', PasswordIssue.sameAsCurrent),
          ('TOO_LONG', PasswordIssue.tooLong),
          ('SAME_AS_LOGIN', PasswordIssue.sameAsLogin),
          ('NEEDS_LETTER', PasswordIssue.needsLetter),
          // Yangi (noma'lum) sabab — baribir zaif parol, umumiy matn.
          ('SOMETHING_NEW', null),
        ]) {
          await expectLater(
            call(
              _repo(
                (_) => (400, {'code': 'WEAK_PASSWORD', 'reason': reason}),
              ).$1,
            ),
            _throwsKirish(KirishError.weakPassword, passwordIssue: issue),
            reason: reason,
          );
        }
        // Boshqa 400 (DTO tekshiruvi) — «zaif parol» emas.
        await expectLater(
          call(
            _repo(
              (_) => (
                400,
                {
                  'statusCode': 400,
                  'message': ['newPassword must be a string'],
                },
              ),
            ).$1,
          ),
          _throwsKirish(KirishError.validation),
        );
      },
    );
  });

  group('tiklash', () {
    test('so\'rov chiptasi va holat (server kanali bilan)', () async {
      final (api, requests) = _repo(
        (o) => o.method == 'POST'
            ? (202, {'requestId': 'rq-1', 'pollToken': 'poll-1'})
            : (
                200,
                {
                  'status': 'RESTORED',
                  'channel': 'PARENT',
                  'createdAt': '2026-11-09T09:00:00.000Z',
                  'restoredAt': '2026-11-09T09:20:00.000Z',
                  'signedOutAt': null,
                },
              ),
      );
      final ticket = await api.requestRecovery(
        login: 'Aziza.K24',
        channel: RecoveryChannel.school,
      );
      expect(ticket.requestId, 'rq-1');
      expect(ticket.channel, RecoveryChannel.school);
      expect(requests.first.data, {'login': 'aziza.k24', 'channel': 'SCHOOL'});

      final status = await api.recoveryStatus(ticket);
      expect(requests.last.path, '/auth/child-recovery/rq-1');
      expect(requests.last.queryParameters, {'token': 'poll-1'});
      expect(status.state, RecoveryState.restored);
      expect(status.channel, RecoveryChannel.parent);
      expect(status.signedOutAt, isNull);
    });

    test('holat: 404 NOT_FOUND — so\'rov endi faol emas', () async {
      final (api, _) = _repo(
        (_) => (
          404,
          {
            'statusCode': 404,
            'code': 'NOT_FOUND',
            'message': 'Request not found',
          },
        ),
      );
      await expectLater(
        api.recoveryStatus(FakeKirishRepository.recoveryTicket),
        _throwsKirish(KirishError.notFound),
      );
    });

    test('limit — rateLimited', () async {
      final (api, _) = _repo((_) => (429, {'code': 'RATE_LIMITED'}));
      await expectLater(
        api.requestRecovery(login: 'a.b1', channel: RecoveryChannel.parent),
        _throwsKirish(KirishError.rateLimited),
      );
    });
  });

  group('maktab kodi', () {
    test(
      'kod va holat; xatolar CODE_INVALID, ALREADY_ENROLLED, LOCKED',
      () async {
        final (ok, requests) = _repo(
          (_) => (
            200,
            {
              'student': {
                'status': 'UNDER_REVIEW',
                'schoolName': null,
                'className': null,
              },
              'parent': {'status': 'PENDING'},
              'expiresAt': '2026-11-10T09:30:12.345Z',
            },
          ),
        );
        final status = await ok.linkSchool('048213');
        expect(requests.single.data, {'code': '048213'});
        expect(status.student, StudentLinkState.underReview);
        expect(status.parent, ParentLinkState.pending);
        expect(status.expiresAt, DateTime.utc(2026, 11, 10, 9, 30, 12, 345));

        await expectLater(
          _repo((_) => (404, {'code': 'CODE_INVALID'})).$1.linkSchool('111111'),
          _throwsKirish(KirishError.codeInvalid),
        );
        await expectLater(
          _repo(
            (_) => (409, {'code': 'ALREADY_ENROLLED'}),
          ).$1.linkSchool('111111'),
          _throwsKirish(KirishError.alreadyEnrolled),
        );
        await expectLater(
          _repo(
            (_) => (429, {'code': 'LOCKED', 'retryAfterSeconds': 842}),
          ).$1.linkSchool('111111'),
          _throwsKirish(
            KirishError.locked,
            retryAfter: const Duration(seconds: 842),
          ),
        );
        // Bola bo'yicha umumiy so'rov chegarasi — blok emas.
        await expectLater(
          _repo(
            (_) => (429, {'message': 'ThrottlerException'}),
          ).$1.linkSchool('111111'),
          _throwsKirish(KirishError.rateLimited),
        );
      },
    );

    test('tuzatish so\'rovi: sabab, izoh va UUID', () async {
      final (api, requests) = _repo(
        (_) => (201, {'id': 'x', 'status': 'OPEN'}),
      );
      await api.requestCorrection(
        note: '  Men 7-B sinfdaman ',
        clientRequestId: '3f9c1c1e-6a1b-4c1e-9d5e-0a3f4b6c7d8e',
      );
      expect(requests.single.path, '/child/school/correction');
      expect(requests.single.data, {
        'reason': 'WRONG_SCHOOL_OR_CLASS',
        'note': 'Men 7-B sinfdaman',
        'clientRequestId': '3f9c1c1e-6a1b-4c1e-9d5e-0a3f4b6c7d8e',
      });
      await expectLater(
        _repo(
          (_) => (429, {'code': 'TOO_MANY_REQUESTS'}),
        ).$1.requestCorrection(note: '', clientRequestId: 'id'),
        _throwsKirish(KirishError.rateLimited),
      );
    });
  });

  test('profil: yosh berilmasa yuborilmaydi', () async {
    final (api, requests) = _repo((_) => (200, {}));
    await api.saveProfile(
      age: null,
      gender: 'female',
      language: EducationLanguage.kaa,
    );
    expect(requests.single.method, 'PUT');
    expect(requests.single.path, '/children/me');
    expect(requests.single.data, {
      'gender': 'female',
      'educationLanguage': 'kaa',
    });
  });
}
