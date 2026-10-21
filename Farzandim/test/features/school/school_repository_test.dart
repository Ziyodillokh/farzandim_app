// SchoolRepository: 12 ta `/parent/school` chaqiruvining yo'li, metodi,
// parametrlari va tanasi; so'rovdan oldingi tekshiruv (keraksiz 400 va kod
// urinishlari sarflanmaydi) va xatolarning SchoolFailure'ga aylanishi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

const _links = {
  'links': [
    {
      'guardianId': 'g-1',
      'fullName': 'Karimova Malika',
      'relation': 'MOTHER',
      'linkedAt': '2026-10-19T08:00:00.000Z',
      'school': {'id': 's-1', 'name': 'Test maktab', 'shortName': 'TM'},
      'students': [
        {
          'id': 'st-1',
          'fullName': 'Karimov Aziz',
          'className': '7-A',
          'childId': null,
          'linkedBy': 'NONE',
        },
      ],
    },
  ],
  'children': [
    {'id': 'kid-1', 'name': 'Aziz'},
  ],
};

Matcher _failure(SchoolFailureKind kind) =>
    throwsA(isA<SchoolFailure>().having((f) => f.kind, 'kind', kind));

void main() {
  late FakeHttpAdapter adapter;
  late SchoolRepository repo;
  var reply = const FakeReply(200);

  setUp(() {
    reply = const FakeReply(200);
    adapter = FakeHttpAdapter((_) => reply);
    repo = SchoolRepository(dio: fakeDio(adapter));
  });

  RequestOptions last() => adapter.requests.last;

  group('A. Bog`lanish', () {
    test('GET /links', () async {
      reply = const FakeReply(200, _links);
      final links = await repo.fetchLinks();
      expect(last().method, 'GET');
      expect(last().path, '/parent/school/links');
      expect(links.links.single.students.single.id, 'st-1');
    });

    test('POST /link — kod normallashtirib yuboriladi', () async {
      reply = const FakeReply(200, _links);
      final links = await repo.redeemInvite(' abcd-2345 ');
      expect(last().method, 'POST');
      expect(last().path, '/parent/school/link');
      expect(last().data, {'code': 'ABCD2345'});
      expect(links.hasLinks, isTrue);
    });

    test('yaroqsiz kod tarmoqqa chiqmaydi', () async {
      await expectLater(
        repo.redeemInvite('AB-12'),
        _failure(SchoolFailureKind.inviteFormat),
      );
      expect(adapter.requests, isEmpty);
    });

    test('INVITE_INVALID va TOO_MANY_ATTEMPTS', () async {
      reply = const FakeReply(404, {
        'statusCode': 404,
        'code': 'INVITE_INVALID',
        'message': 'Invite code is invalid or expired',
      });
      await expectLater(
        repo.redeemInvite('ABCD2345'),
        _failure(SchoolFailureKind.inviteInvalid),
      );
      reply = const FakeReply(429, {
        'statusCode': 429,
        'code': 'TOO_MANY_ATTEMPTS',
        'message': 'Too many invalid invite codes',
      });
      await expectLater(
        repo.redeemInvite('ABCD2345'),
        _failure(SchoolFailureKind.tooManyAttempts),
      );
    });

    test('PUT /students/:id/child — moslash va olib tashlash', () async {
      reply = const FakeReply(200, _links);
      await repo.setStudentChild(studentId: 'st-1', childId: 'kid-1');
      expect(last().method, 'PUT');
      expect(last().path, '/parent/school/students/st-1/child');
      expect(last().data, {'childId': 'kid-1'});
      await repo.setStudentChild(studentId: 'st-1', childId: null);
      expect(last().data, {'childId': null});
    });

    test('DELETE /links/:guardianId (204)', () async {
      reply = const FakeReply(204);
      await repo.unlink('g-1');
      expect(last().method, 'DELETE');
      expect(last().path, '/parent/school/links/g-1');
    });

    test('bo`sh id — so`rovsiz validation (404 "unavailable" emas)', () async {
      await expectLater(
        repo.unlink(' '),
        _failure(SchoolFailureKind.validation),
      );
      await expectLater(
        repo.setStudentChild(studentId: '', childId: 'kid-1'),
        _failure(SchoolFailureKind.validation),
      );
      expect(adapter.requests, isEmpty);
    });

    test('backend deploy qilinmagan (404, code yo`q) → unavailable', () async {
      reply = const FakeReply(404, {
        'statusCode': 404,
        'message': 'Cannot GET /api/parent/school/links',
        'error': 'Not Found',
      });
      await expectLater(
        repo.fetchLinks(),
        _failure(SchoolFailureKind.unavailable),
      );
    });

    test('internet yo`q → network', () async {
      reply = const FakeReply.offline();
      await expectLater(repo.fetchLinks(), _failure(SchoolFailureKind.network));
    });
  });

  group('B. Xabarlar', () {
    test('GET /announcements — sahifa va limit chegarasi (≤ 50)', () async {
      reply = const FakeReply(200, {
        'items': [
          {'id': 'a-1', 'title': 'E`lon', 'priority': 'NORMAL'},
        ],
        'pagination': {'page': 2, 'limit': 50, 'total': 51, 'totalPages': 2},
        'unread': 3,
      });
      final page = await repo.fetchAnnouncements(page: 2, limit: 500);
      expect(last().path, '/parent/school/announcements');
      expect(last().queryParameters, {'page': 2, 'limit': 50});
      expect(page.items.single.id, 'a-1');
      expect(page.unread, 3);
      expect(page.hasMore, isFalse);

      await repo.fetchAnnouncements(page: 0, limit: 0);
      expect(last().queryParameters, {'page': 1, 'limit': 1});
    });

    test('POST /announcements/:id/read → server readAt', () async {
      reply = const FakeReply(200, {
        'id': 'a-1',
        'readAt': '2026-10-20T04:00:00.000Z',
      });
      final readAt = await repo.markAnnouncementRead('a-1');
      expect(last().method, 'POST');
      expect(last().path, '/parent/school/announcements/a-1/read');
      expect(readAt, DateTime.utc(2026, 10, 20, 4).toLocal());
    });

    test('GET /payments va GET /verifications (massiv javob)', () async {
      reply = const FakeReply(200, [
        {'id': 'p-1', 'nextDate': '2099-04-05', 'openVerification': false},
        'buzuq',
      ]);
      final payments = await repo.fetchPayments();
      expect(last().path, '/parent/school/payments');
      expect(payments.single.id, 'p-1');

      reply = const FakeReply(200, [
        {'id': 'v-1', 'status': 'ANSWERED', 'answer': 'Qabul qilindi'},
      ]);
      final verifications = await repo.fetchVerifications();
      expect(last().path, '/parent/school/verifications');
      expect(verifications.single.answer, 'Qabul qilindi');
    });

    test('massiv o`rniga obyekt kelsa — bo`sh ro`yxat', () async {
      reply = const FakeReply(200, {'items': <Object>[]});
      expect(await repo.fetchPayments(), isEmpty);
    });

    test('POST /verifications — xabar qirqiladi, chegaralar', () async {
      reply = const FakeReply(201, {'id': 'v-1', 'status': 'OPEN'});
      final created = await repo.createVerification(
        paymentReminderId: 'p-1',
        message: "  To'laganman  ",
      );
      expect(last().method, 'POST');
      expect(last().path, '/parent/school/verifications');
      expect(last().data, {
        'paymentReminderId': 'p-1',
        'message': "To'laganman",
      });
      expect(created.isOpen, isTrue);

      final count = adapter.requests.length;
      await expectLater(
        repo.createVerification(paymentReminderId: 'p-1', message: '   '),
        _failure(SchoolFailureKind.validation),
      );
      await expectLater(
        repo.createVerification(paymentReminderId: 'p-1', message: 'x' * 501),
        _failure(SchoolFailureKind.validation),
      );
      expect(adapter.requests, hasLength(count));
    });

    test('409 ochiq so`rov → verificationOpen', () async {
      reply = const FakeReply(409, {
        'statusCode': 409,
        'code': 'CONFLICT',
        'message': 'open verification exists',
      });
      await expectLater(
        repo.createVerification(paymentReminderId: 'p-1', message: 'x'),
        _failure(SchoolFailureKind.verificationOpen),
      );
    });
  });

  group('C. Davomat', () {
    test('POST /early-exits — bugun uchun, maydonlar qirqiladi', () async {
      reply = const FakeReply(201, {
        'id': 'e-1',
        'status': 'PENDING',
        'requestedByMe': true,
      });
      final created = await repo.requestEarlyExit(
        studentId: 'st-1',
        time: '12:30',
        reason: ' Shifokor qabuli ',
        pickupBy: ' Onasi ',
      );
      expect(last().method, 'POST');
      expect(last().path, '/parent/school/early-exits');
      expect(last().data, {
        'studentId': 'st-1',
        'time': '12:30',
        'reason': 'Shifokor qabuli',
        'pickupBy': 'Onasi',
      });
      expect(created.isPending, isTrue);
    });

    test(
      'erta ketish: vaqt va matn chegaralari so`rovsiz tekshiriladi',
      () async {
        Future<void> bad({
          String time = '12:30',
          String reason = 'Sabab',
          String pickupBy = 'Onasi',
        }) => expectLater(
          repo.requestEarlyExit(
            studentId: 'st-1',
            time: time,
            reason: reason,
            pickupBy: pickupBy,
          ),
          _failure(SchoolFailureKind.validation),
        );
        await bad(time: '25:00');
        await bad(time: '9:05');
        await bad(reason: '  ');
        await bad(reason: 'x' * 161);
        await bad(pickupBy: '');
        await bad(pickupBy: 'x' * 81);
        expect(adapter.requests, isEmpty);
      },
    );

    test('409 bugungi kutilayotgan so`rov → earlyExitPending', () async {
      reply = const FakeReply(409, {
        'statusCode': 409,
        'code': 'CONFLICT',
        'message': 'pending',
      });
      await expectLater(
        repo.requestEarlyExit(
          studentId: 'st-1',
          time: '12:30',
          reason: 'Sabab',
          pickupBy: 'Onasi',
        ),
        _failure(SchoolFailureKind.earlyExitPending),
      );
    });

    test('GET /early-exits', () async {
      reply = const FakeReply(200, [
        {'id': 'e-1', 'status': 'APPROVED', 'requestedByMe': false},
      ]);
      final list = await repo.fetchEarlyExits();
      expect(last().path, '/parent/school/early-exits');
      expect(list.single.requestedByMe, isFalse);
    });

    test('GET /attendance — oy ixtiyoriy, format tekshiriladi', () async {
      reply = const FakeReply(200, {
        'student': {'id': 'st-1', 'name': 'Aliyev Vali'},
        'month': '2026-10',
        'days': <Object>[],
        'summary': <String, Object>{},
        'rate': 0,
      });
      final month = await repo.fetchAttendance(
        studentId: 'st-1',
        month: '2026-10',
      );
      expect(last().path, '/parent/school/attendance');
      expect(last().queryParameters, {'studentId': 'st-1', 'month': '2026-10'});
      expect(month.student.name, 'Aliyev Vali');

      await repo.fetchAttendance(studentId: 'st-1');
      expect(last().queryParameters, {'studentId': 'st-1'});

      final count = adapter.requests.length;
      await expectLater(
        repo.fetchAttendance(studentId: 'st-1', month: '2026-13'),
        _failure(SchoolFailureKind.validation),
      );
      expect(adapter.requests, hasLength(count));
    });

    test('begona o`quvchi (404 NOT_FOUND) — unavailable EMAS', () async {
      reply = const FakeReply(404, {
        'statusCode': 404,
        'code': 'NOT_FOUND',
        'message': 'st-9',
      });
      await expectLater(
        repo.fetchAttendance(studentId: 'st-9'),
        _failure(SchoolFailureKind.notFound),
      );
    });
  });
}
