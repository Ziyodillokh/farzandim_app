// SchoolConnectRepository: kontaktlar, yozishmalar va statistika
// chaqiruvlarining yo'li, metodi va tanasi; so'rovdan oldingi tekshiruv va
// yangi xato turlari (kunlik chegara, xodim endi kontakt emas).

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/data/school_connect_repository.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

const _thread = {
  'id': 'th-1',
  'status': 'OPEN',
  'schoolName': '24-maktab',
  'staff': {
    'id': 'stf-h',
    'fullName': 'Rasulova Malika',
    'role': 'HOMEROOM',
    'position': '',
  },
  'student': {'id': 'st-1', 'name': 'Karimova Aziza', 'className': '6-B'},
  'lastAuthor': 'STAFF',
  'lastMessageAt': '2026-11-09T03:14:00.000Z',
  'unread': 1,
  'available': true,
  'messages': [
    {
      'id': 'm-1',
      'author': 'PARENT',
      'topic': 'ABSENCE',
      'body': 'Bugun kela olmaydi',
      'createdAt': '2026-11-09T02:32:00.000Z',
      'seen': true,
    },
    {
      'id': 'm-2',
      'author': 'STAFF',
      'topic': null,
      'body': 'Rahmat',
      'createdAt': '2026-11-09T03:14:00.000Z',
      'seen': false,
    },
  ],
};

Matcher _failure(SchoolFailureKind kind) =>
    throwsA(isA<SchoolFailure>().having((f) => f.kind, 'kind', kind));

void main() {
  late FakeHttpAdapter adapter;
  late SchoolConnectRepository repo;
  var reply = const FakeReply(200);

  setUp(() {
    reply = const FakeReply(200);
    adapter = FakeHttpAdapter((_) => reply);
    repo = SchoolConnectRepository(dio: fakeDio(adapter));
  });

  RequestOptions last() => adapter.requests.last;

  test('GET /contacts?studentId= — guruhlar va yozishma holati', () async {
    reply = const FakeReply(200, {
      'student': {'id': 'st-1', 'name': 'Karimova Aziza', 'className': '6-B'},
      'contacts': [
        {
          'staffId': 'stf-h',
          'fullName': 'Rasulova Malika',
          'role': 'HOMEROOM',
          'position': "Ona tili o'qituvchisi",
          'group': 'CLASS',
          'threadId': 'th-1',
          'unread': 2,
          'lastMessageAt': '2026-11-09T03:14:00.000Z',
        },
        {
          'staffId': 'stf-p',
          'fullName': 'Ergasheva Nodira',
          'role': 'PSYCHOLOGIST',
          'position': '',
          'group': 'SUPPORT',
          'threadId': null,
          'unread': 0,
        },
        {'staffId': '', 'fullName': 'buzuq'},
      ],
    });
    final contacts = await repo.fetchContacts('st-1');
    expect(last().method, 'GET');
    expect(last().path, '/parent/school/contacts');
    expect(last().queryParameters, {'studentId': 'st-1'});
    expect(contacts.contacts, hasLength(2));
    final homeroom = contacts.inGroup(ContactGroup.classTeacher).single;
    expect(homeroom.threadId, 'th-1');
    expect(homeroom.unread, 2);
    expect(
      contacts.inGroup(ContactGroup.support).single.isConfidential,
      isTrue,
    );
  });

  test('GET /threads/:id — xabarlar, mavzu va "o`qildi"', () async {
    reply = const FakeReply(200, _thread);
    final thread = await repo.fetchThread('th-1');
    expect(last().path, '/parent/school/threads/th-1');
    expect(thread.staff.role, StaffRole.homeroom);
    expect(thread.lastFromStaff, isTrue);
    expect(thread.messages.first.topic, ContactTopic.absence);
    expect(thread.messages.first.mine, isTrue);
    expect(thread.messages.first.seen, isTrue);
    expect(thread.messages.last.mine, isFalse);
  });

  test(
    'POST /threads — mavzu, matn (qirqilgan) va idempotentlik kaliti',
    () async {
      reply = const FakeReply(201, _thread);
      await repo.startThread(
        staffId: 'stf-h',
        studentId: 'st-1',
        topic: ContactTopic.absence,
        body: '  Salom\r\nustoz  ',
      );
      expect(last().method, 'POST');
      expect(last().path, '/parent/school/threads');
      final data = last().data as Map<String, dynamic>;
      expect(data['staffId'], 'stf-h');
      expect(data['studentId'], 'st-1');
      expect(data['topic'], 'ABSENCE');
      expect(data['body'], 'Salom\nustoz');
      expect(data['clientMessageId'], matches(RegExp(r'^[0-9a-f]{24}$')));
    },
  );

  test('POST /threads/:id/messages — mavzusiz xabarda topic yo`q', () async {
    reply = const FakeReply(201, _thread);
    await repo.sendMessage(threadId: 'th-1', body: 'Rahmat');
    expect(last().path, '/parent/school/threads/th-1/messages');
    expect((last().data as Map).containsKey('topic'), isFalse);
  });

  test('bo`sh yoki 1000 belgidan uzun matn so`rovsiz rad etiladi', () async {
    final before = adapter.requests.length;
    await expectLater(
      repo.sendMessage(threadId: 'th-1', body: '   '),
      _failure(SchoolFailureKind.validation),
    );
    await expectLater(
      repo.sendMessage(threadId: 'th-1', body: 'x' * 1001),
      _failure(SchoolFailureKind.validation),
    );
    expect(adapter.requests.length, before);
  });

  test('429 RATE_LIMITED va 409 "contact unavailable" — o`z turlari', () async {
    reply = const FakeReply(429, {
      'code': 'RATE_LIMITED',
      'message': 'messages per day',
    });
    await expectLater(
      repo.sendMessage(threadId: 'th-1', body: 'Salom'),
      _failure(SchoolFailureKind.rateLimited),
    );
    reply = const FakeReply(409, {
      'code': 'CONFLICT',
      'message': 'contact unavailable',
    });
    await expectLater(
      repo.sendMessage(threadId: 'th-1', body: 'Salom'),
      _failure(SchoolFailureKind.contactUnavailable),
    );
  });

  test('GET /students/:id/overview — davr, davomat, vazifalar', () async {
    reply = const FakeReply(200, {
      'student': {
        'id': 'st-1',
        'name': 'Karimova Aziza',
        'className': '6-B',
        'schoolName': '24-maktab',
      },
      'period': {
        'kind': 'QUARTER',
        'no': 2,
        'from': '2026-11-09',
        'to': '2026-11-20',
      },
      'attendance': {
        'present': 9,
        'late': 1,
        'absent': 0,
        'leftEarly': 0,
        'excused': 0,
        'pending': 1,
        'total': 11,
        'rate': 100,
        'averageArrival': '08:09',
        'onTimeStreak': 4,
        'classRate': null,
        'weeks': [
          {'weekStart': '2026-11-09', 'rate': 100},
          {'weekStart': '2026-11-16', 'rate': null},
        ],
      },
      'tasks': {
        'total': 2,
        'submitted': 1,
        'accepted': 1,
        'returned': 0,
        'pending': 0,
        'overdue': 1,
        'classSubmitRate': 74,
        'items': [
          {
            'id': 'a-1',
            'title': 'Insho',
            'dueDate': '2026-11-18',
            'state': 'OVERDUE',
            'teacher': null,
          },
        ],
      },
    });
    final o = await repo.fetchOverview('st-1');
    expect(last().path, '/parent/school/students/st-1/overview');
    expect(o.period.isQuarter, isTrue);
    expect(o.period.number, 2);
    expect(o.attendance.marked, 10);
    expect(o.attendance.attended, 10);
    expect(o.attendance.classRate, isNull);
    expect(o.attendance.weeks.last.rate, isNull);
    expect(o.tasks.submitRate, 50);
    expect(o.tasks.items.single.state, TaskState.overdue);
  });

  test('topicsFor: rolga mos shablonlar, psixologda maxfiy mavzular', () {
    expect(topicsFor(StaffRole.homeroom).first, ContactTopic.absence);
    expect(topicsFor(StaffRole.psychologist), contains(ContactTopic.bullying));
    expect(topicsFor(StaffRole.admin), contains(ContactTopic.payment));
    for (final role in StaffRole.values) {
      expect(topicsFor(role), isNotEmpty, reason: role.name);
      expect(topicsFor(role), isNot(contains(ContactTopic.other)));
    }
  });
}
