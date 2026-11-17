// Kirish ma'lumotlari modellari: server javobini xavfsiz o'qish (hech qachon
// otmaydi), "birinchi kirish kutilmoqda" holati, parolni log'dan yashirish va
// "parolni unutdim" ro'yxatining turli shakllari.

import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChildCredentials.tryParse', () {
    test("vaqtinchalik parol muddati (14 kun) o'qiladi", () {
      final c = ChildCredentials.tryParse({
        'login': 'aziza.k24',
        'issuedBy': 'SCHOOL',
        'mustChangePassword': true,
        'issuedAt': '2026-11-09T09:00:00.000Z',
        'temporaryPasswordExpiresAt': '2026-11-23T09:00:00.000Z',
      });
      expect(
        c?.temporaryPasswordExpiresAt?.toUtc(),
        DateTime.utc(2026, 11, 23, 9),
      );
    });

    test('to`liq javob', () {
      final credentials = ChildCredentials.tryParse(const {
        'login': 'aziza.k24',
        'issuedBy': 'PARENT',
        'issuedAt': '2026-11-06T08:30:00.000Z',
        'mustChangePassword': true,
        'lastLoginAt': null,
      });
      expect(credentials, isNotNull);
      expect(credentials!.login, 'aziza.k24');
      expect(credentials.issuedBy, CredentialsIssuer.parent);
      expect(credentials.issuedAt, DateTime.utc(2026, 11, 6, 8, 30).toLocal());
      expect(credentials.isFirstLoginPending, isTrue);
      expect(credentials.neverLoggedIn, isTrue);
    });

    test('bola kirgan va o`z parolini o`rnatgan', () {
      final credentials = ChildCredentials.tryParse(const {
        'login': 'aziza.k24',
        'issuedBy': 'SCHOOL',
        'issuedAt': '2026-11-01T08:30:00.000Z',
        'mustChangePassword': false,
        'lastLoginAt': '2026-11-05T17:45:00.000Z',
      });
      expect(credentials!.issuedBy, CredentialsIssuer.school);
      expect(credentials.isFirstLoginPending, isFalse);
      expect(credentials.neverLoggedIn, isFalse);
      expect(
        credentials.lastLoginAt,
        DateTime.utc(2026, 11, 5, 17, 45).toLocal(),
      );
    });

    test('berilmagan: null, bo`sh tana, obyekt emas, loginsiz', () {
      expect(ChildCredentials.tryParse(null), isNull);
      expect(ChildCredentials.tryParse(''), isNull);
      expect(ChildCredentials.tryParse('null'), isNull);
      expect(ChildCredentials.tryParse(const <dynamic>[]), isNull);
      expect(ChildCredentials.tryParse(const <String, dynamic>{}), isNull);
      expect(ChildCredentials.tryParse(const {'login': ''}), isNull);
      expect(ChildCredentials.tryParse(const {'login': 42}), isNull);
    });

    test('noma`lum `issuedBy` va buzuq sana otmaydi', () {
      final credentials = ChildCredentials.tryParse(const {
        'login': 'aziza.k24',
        'issuedBy': 'ADMIN',
        'issuedAt': 'kecha',
        'mustChangePassword': 'ha',
        'lastLoginAt': 123,
      });
      expect(credentials!.issuedBy, CredentialsIssuer.unknown);
      expect(credentials.issuedAt, isNull);
      expect(credentials.lastLoginAt, isNull);
      expect(credentials.isFirstLoginPending, isFalse);
    });

    test('Map<dynamic, dynamic> ham o`qiladi; tenglik qiymat bo`yicha', () {
      final a = ChildCredentials.tryParse(<dynamic, dynamic>{
        'login': 'aziza.k24',
        'issuedBy': 'PARENT',
        'mustChangePassword': true,
      });
      final b = ChildCredentials.tryParse(const {
        'login': 'aziza.k24',
        'issuedBy': 'PARENT',
        'mustChangePassword': true,
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('IssuedCredentials', () {
    test('login va parol bor — o`qiladi', () {
      final issued = IssuedCredentials.tryParse(const {
        'login': 'aziza.k24',
        'temporaryPassword': 'k7m2xq9p',
        'issuedAt': '2026-11-06T08:30:00.000Z',
      });
      expect(issued!.login, 'aziza.k24');
      expect(issued.temporaryPassword, 'k7m2xq9p');
      expect(issued.issuedAt, isNotNull);
    });

    test('parol yoki login yo`q — null (ko`rsatadigan narsa yo`q)', () {
      expect(IssuedCredentials.tryParse(null), isNull);
      expect(IssuedCredentials.tryParse(const {'login': 'a1b2'}), isNull);
      expect(
        IssuedCredentials.tryParse(const {
          'login': 'a1b2',
          'temporaryPassword': '',
        }),
        isNull,
      );
      expect(
        IssuedCredentials.tryParse(const {'temporaryPassword': 'k7m2xq9p'}),
        isNull,
      );
    });

    test('toString parolni yashiradi (log va xato xabariga tushmasin)', () {
      const issued = IssuedCredentials(
        login: 'aziza.k24',
        temporaryPassword: 'k7m2xq9p',
      );
      expect(issued.toString(), isNot(contains('k7m2xq9p')));
      expect('$issued', contains('aziza.k24'));
      expect('${[issued]}', isNot(contains('k7m2xq9p')));
    });
  });

  group('RecoveryRequest', () {
    const open = {
      'id': 'r-1',
      'channel': 'PARENT',
      'status': 'RECEIVED',
      'createdAt': '2026-11-06T08:00:00.000Z',
    };

    test('element: ochiq so`rov', () {
      final request = RecoveryRequest.tryParse(open);
      expect(request!.id, 'r-1');
      expect(request.channel, RecoveryChannel.parent);
      expect(request.status, RecoveryStatus.received);
      expect(request.isOpen, isTrue);
      expect(request.createdAt, DateTime.utc(2026, 11, 6, 8).toLocal());
    });

    test('hal bo`lgan va noma`lum holatlar ochiq emas', () {
      for (final status in ['RESTORED', 'REJECTED', 'NEW', null]) {
        final request = RecoveryRequest.tryParse({...open, 'status': status});
        expect(request!.isOpen, isFalse, reason: '$status');
      }
    });

    test('id yo`q — element tashlanadi', () {
      expect(RecoveryRequest.tryParse({...open, 'id': ''}), isNull);
      expect(RecoveryRequest.tryParse(const {'status': 'RECEIVED'}), isNull);
    });

    test('ro`yxat: massiv, `requests` yoki `items` ichida', () {
      expect(parseRecoveryRequests([open]), hasLength(1));
      expect(
        parseRecoveryRequests({
          'requests': [open],
        }),
        hasLength(1),
      );
      expect(
        parseRecoveryRequests({
          'items': [open],
        }),
        hasLength(1),
      );
    });

    test('noto`g`ri shakl yoki buzuq element — bo`sh/tashlanadi', () {
      expect(parseRecoveryRequests(null), isEmpty);
      expect(parseRecoveryRequests(''), isEmpty);
      expect(parseRecoveryRequests('xato'), isEmpty);
      expect(parseRecoveryRequests({'requests': 'yo`q'}), isEmpty);
      expect(
        parseRecoveryRequests([
          open,
          42,
          null,
          'x',
          {'a': 1},
        ]),
        hasLength(1),
      );
    });

    test('yangisi birinchi, sanasizlar oxirida; ro`yxat o`zgarmas', () {
      final list = parseRecoveryRequests([
        {...open, 'id': 'old', 'createdAt': '2026-11-01T08:00:00.000Z'},
        {...open, 'id': 'no-date', 'createdAt': null},
        {...open, 'id': 'new', 'createdAt': '2026-11-06T09:00:00.000Z'},
      ]);
      expect(list.map((r) => r.id), ['new', 'old', 'no-date']);
      expect(() => list.add(list.first), throwsUnsupportedError);
    });
  });
}
