// Maktab modellari: backend e2e javoblari shaklidagi fixture'lar
// (school-guardians, school-comms-parent, school-attendance-history),
// noma'lum enum qiymatlari va yo'q / noto'g'ri turdagi maydonlar —
// parse hech qachon otmasligi kerak.

import 'dart:convert';

import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1x1 shaffof PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB'
    '0C8AAAAASUVORK5CYII=';

Map<String, dynamic> _linksJson() => {
  'links': [
    {
      'guardianId': 'g-1',
      'fullName': 'Karimova Malika',
      'relation': 'MOTHER',
      'linkedAt': '2026-10-19T08:00:00.000Z',
      'school': {
        'id': 's-1',
        'name': 'Test maktab',
        'shortName': '1-maktab',
        'logo': 'data:image/png;base64,$_pngBase64',
        'city': 'Toshkent',
      },
      'students': [
        {
          'id': 'st-1',
          'fullName': 'Karimov Aziz Akmalovich',
          'className': '7-A',
          'childId': 'kid-1',
          'linkedBy': 'ME',
        },
        {
          'id': 'st-2',
          'fullName': 'Karimova Laylo',
          'className': '3-B',
          'childId': null,
          'linkedBy': 'NONE',
        },
        {
          'id': 'st-3',
          'fullName': 'Karimov Bek',
          'className': '9-V',
          'childId': null,
          'linkedBy': 'OTHER',
        },
      ],
    },
    {
      'guardianId': 'g-2',
      'fullName': 'Karimova M.',
      'relation': 'OTHER',
      'linkedAt': null,
      'school': {
        'id': 's-1',
        'name': 'Test maktab',
        'shortName': '',
        'logo': null,
        'city': '',
      },
      'students': [
        // Ikkinchi vasiy yozuvi orqali ham bog'langan — bir marta sanaladi.
        {
          'id': 'st-2',
          'fullName': 'Karimova Laylo',
          'className': '3-B',
          'childId': null,
          'linkedBy': 'NONE',
        },
      ],
    },
  ],
  'children': [
    {'id': 'kid-1', 'name': 'Aziz'},
    {'id': 'kid-2', 'name': 'Laylo'},
  ],
};

void main() {
  group('SchoolLinks', () {
    test('backend javobi to`liq parse bo`ladi', () {
      final links = SchoolLinks.fromJson(_linksJson());
      expect(links.available, isTrue);
      expect(links.hasLinks, isTrue);
      expect(links.links, hasLength(2));
      expect(links.children.map((c) => c.name), ['Aziz', 'Laylo']);

      final first = links.links.first;
      expect(first.guardianId, 'g-1');
      expect(first.relation, GuardianRelation.mother);
      expect(first.linkedAt, DateTime.utc(2026, 10, 19, 8).toLocal());
      expect(first.school.name, 'Test maktab');
      expect(first.school.displayName, '1-maktab');
      expect(first.school.logoBytes, isNotNull);
      expect(first.school.logoBytes, base64Decode(_pngBase64));
      expect(first.students.first.linkedBy, LinkedBy.me);
      expect(first.students.first.isMatchedToMine, isTrue);

      final second = links.links.last;
      expect(second.linkedAt, isNull);
      expect(second.school.displayName, 'Test maktab');
      expect(second.school.logoBytes, isNull);
    });

    test('o`quvchilar takrorlanmaydi; moslash holatlari', () {
      final links = SchoolLinks.fromJson(_linksJson());
      expect(links.students.map((s) => s.id), ['st-1', 'st-2', 'st-3']);
      expect(links.studentForChild('kid-1')?.id, 'st-1');
      expect(links.studentForChild('kid-2'), isNull);
      expect(links.unmatchedStudents.map((s) => s.id), ['st-2']);
      expect(links.students.last.isMatchedByOther, isTrue);
      expect(links.students.last.needsMatch, isFalse);
      expect(links.linkOfStudent('st-3')?.guardianId, 'g-1');
      expect(links.linkOfStudent('nope'), isNull);
    });

    test('qiymat bo`yicha tenglik (polling dedup uchun)', () {
      expect(
        SchoolLinks.fromJson(_linksJson()),
        SchoolLinks.fromJson(_linksJson()),
      );
      expect(SchoolLinks.empty, isNot(SchoolLinks.unavailable));
    });

    test('noma`lum enum → unknown', () {
      final links = SchoolLinks.fromJson(const {
        'links': [
          {
            'guardianId': 'g-1',
            'relation': 'COUSIN',
            'school': {'id': 's-1', 'name': 'M'},
            'students': [
              {'id': 'st-1', 'linkedBy': 'TEACHER'},
            ],
          },
        ],
      });
      final link = links.links.single;
      expect(link.relation, GuardianRelation.unknown);
      expect(link.students.single.linkedBy, LinkedBy.unknown);
      expect(link.students.single.needsMatch, isFalse);
    });

    test('bo`sh, null va noto`g`ri turdagi maydonlar — otmaydi', () {
      expect(SchoolLinks.fromJson(const {}), SchoolLinks.empty);
      final links = SchoolLinks.fromJson(const {
        'links': [
          'buzuq',
          null,
          // id yo'q — aloqani uzib bo'lmaydi, tashlanadi.
          {'fullName': 'Id yo`q'},
          {
            'guardianId': 'g-1',
            'fullName': 42,
            'linkedAt': 'kecha',
            'school': 'maktab',
            'students': 'yo`q',
          },
        ],
        'children': {'id': 'x'},
      });
      final link = links.links.single;
      expect(link.fullName, '');
      expect(link.linkedAt, isNull);
      expect(link.school.id, '');
      expect(link.students, isEmpty);
      expect(links.children, isEmpty);
    });

    test('logo: rasm bo`lmagan yoki buzuq data URI — null', () {
      expect(decodeSchoolLogo(null), isNull);
      expect(decodeSchoolLogo('https://cdn/logo.png'), isNull);
      expect(decodeSchoolLogo('data:text/plain;base64,aGVsbG8='), isNull);
      expect(decodeSchoolLogo('data:image/png;base64,%%%'), isNull);
      expect(decodeSchoolLogo('data:image/png;base64,'), isNull);
    });
  });

  group('AnnouncementPage', () {
    test('sahifa, o`qilmaganlar va e`lonlar', () {
      final page = AnnouncementPage.fromJson(const {
        'items': [
          {
            'id': 'a-2',
            'schoolId': 's-1',
            'schoolName': 'Test maktab',
            'title': 'Sinfga',
            'body': 'Ertaga yig`ilish',
            'priority': 'IMPORTANT',
            'sentAt': '2026-10-19T09:00:00.000Z',
            'readAt': null,
          },
          {
            'id': 'a-1',
            'schoolId': 's-1',
            'schoolName': 'Test maktab',
            'title': 'Birinchi',
            'body': '',
            'priority': 'URGENT',
            'sentAt': null,
            'readAt': '2026-10-19T10:00:00.000Z',
          },
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 21, 'totalPages': 2},
        'unread': 1,
      });
      expect(page.items.map((a) => a.id), ['a-2', 'a-1']);
      expect(page.unread, 1);
      expect(page.hasMore, isTrue);
      expect(page.items.first.isImportant, isTrue);
      expect(page.items.first.isRead, isFalse);
      expect(page.items.last.priority, AnnouncementPriority.unknown);
      expect(page.items.last.sentAt, isNull);
      expect(page.items.last.isRead, isTrue);
    });

    test('markedRead — yangi nusxa, avvalgi readAt saqlanadi', () {
      final page = AnnouncementPage.fromJson(const {
        'items': [
          {'id': 'a-1', 'readAt': null},
          {'id': 'a-2', 'readAt': '2026-10-19T10:00:00.000Z'},
        ],
      });
      final at = DateTime(2026, 10, 20, 9);
      final unread = page.items.first;
      final read = unread.markedRead(at);
      expect(read.readAt, at);
      expect(unread.readAt, isNull, reason: 'asl obyekt o`zgarmaydi');
      final already = page.items.last;
      expect(already.markedRead(at).readAt, already.readAt);
    });

    test('bo`sh javob — standart sahifa', () {
      final page = AnnouncementPage.fromJson(const {});
      expect(page.items, isEmpty);
      expect(page.page, 1);
      expect(page.limit, kAnnouncementsPageSize);
      expect(page.hasMore, isFalse);
      expect(page.unread, 0);
    });
  });

  group('To`lovlar', () {
    test('eslatma (e2e javobi) parse bo`ladi', () {
      final p = SchoolPaymentReminder.fromJson(const {
        'id': 'p-1',
        'schoolId': 's-1',
        'schoolName': 'Test maktab',
        'nextDate': '2099-04-05',
        'prepaidMonths': 2,
        'paused': false,
        'children': [
          {'id': 'st-1', 'name': 'Aliyev Vali', 'className': '7-A'},
        ],
        'openVerification': true,
      });
      expect(p.nextDate, '2099-04-05');
      expect(p.nextDay, DateTime(2099, 4, 5));
      expect(p.prepaidMonths, 2);
      expect(p.paused, isFalse);
      expect(p.children.single.name, 'Aliyev Vali');
      expect(p.openVerification, isTrue);
    });

    test('buzuq maydonlar — standart qiymatlar', () {
      final p = SchoolPaymentReminder.fromJson(const {
        'id': 'p-1',
        'nextDate': 5,
        'prepaidMonths': '3',
        'paused': 'ha',
        'children': null,
      });
      expect(p.nextDate, '');
      expect(p.nextDay, isNull);
      expect(p.prepaidMonths, 3);
      expect(p.paused, isFalse);
      expect(p.children, isEmpty);
    });

    test('tekshiruv so`rovi holatlari, noma`lum → unknown', () {
      PaymentVerification v(Object? status) => PaymentVerification.fromJson({
        'id': 'v-1',
        'paymentReminderId': 'p-1',
        'status': status,
        'answer': null,
        'createdAt': '2026-10-19T08:00:00.000Z',
      });
      expect(v('OPEN').status, VerificationStatus.open);
      expect(v('OPEN').isOpen, isTrue);
      expect(v('ANSWERED').status, VerificationStatus.answered);
      expect(v('CLOSED').status, VerificationStatus.closed);
      expect(v('ESCALATED').status, VerificationStatus.unknown);
      expect(v(null).answer, isNull);
      expect(v(null).createdAt, isNotNull);
    });
  });

  group('MonthAttendance', () {
    Map<String, dynamic> month() => {
      'student': {
        'id': 'st-1',
        'name': 'Aliyev Vali',
        'className': '7-A',
        'schoolName': 'Test maktab',
      },
      'month': '2026-10',
      'days': [
        {
          'date': '2026-10-16',
          'schoolDay': true,
          'record': {'status': 'ABSENT', 'inAt': null, 'outAt': null},
        },
        {'date': '2026-10-18', 'schoolDay': false, 'record': null},
        {
          'date': '2026-10-19',
          'schoolDay': true,
          'record': {'status': 'PRESENT', 'inAt': '08:01', 'outAt': '13:30'},
        },
        {'date': '2026-10-20', 'schoolDay': true, 'record': null},
        {
          'date': '2026-10-21',
          'schoolDay': true,
          'record': {'status': 'SICK'},
        },
      ],
      'summary': {
        'present': 1,
        'late': 0,
        'absent': 1,
        'leftEarly': 0,
        'excused': 0,
        'pending': 1,
        'total': 3,
      },
      'rate': 50,
    };

    test('kalendar, jami va foiz', () {
      final m = MonthAttendance.fromJson(month());
      expect(m.student.name, 'Aliyev Vali');
      expect(m.student.schoolName, 'Test maktab');
      expect(m.month, '2026-10');
      expect(m.days, hasLength(5));
      expect(m.summary.present, 1);
      expect(m.summary.absent, 1);
      expect(m.summary.pending, 1);
      expect(m.rate, 50);

      final present = m.dayOf('2026-10-19')!;
      expect(present.record!.status, AttendanceStatus.present);
      expect(present.record!.status.attended, isTrue);
      expect(present.record!.inAt, '08:01');
      expect(present.record!.outAt, '13:30');
      expect(present.day, DateTime(2026, 10, 19));
      expect(m.dayOf('2026-10-18')!.schoolDay, isFalse);
      expect(m.dayOf('2026-10-20')!.isPending, isTrue);
      expect(m.dayOf('2026-10-18')!.isPending, isFalse);
      expect(m.dayOf('2026-10-31'), isNull);
    });

    test('noma`lum holat → unknown; barcha holatlar', () {
      final m = MonthAttendance.fromJson(month());
      expect(m.dayOf('2026-10-21')!.record!.status, AttendanceStatus.unknown);
      expect(AttendanceStatus.fromApi('LATE'), AttendanceStatus.late);
      expect(
        AttendanceStatus.fromApi('LEFT_EARLY'),
        AttendanceStatus.leftEarly,
      );
      expect(AttendanceStatus.fromApi('EXCUSED'), AttendanceStatus.excused);
      expect(AttendanceStatus.leftEarly.attended, isTrue);
      expect(AttendanceStatus.absent.attended, isFalse);
      expect(AttendanceStatus.excused.attended, isFalse);
    });

    test('bo`sh javob va chegaradan tashqari foiz — otmaydi', () {
      final empty = MonthAttendance.fromJson(const {});
      expect(empty.days, isEmpty);
      expect(empty.summary.total, 0);
      expect(empty.rate, 0);
      expect(MonthAttendance.fromJson(const {'rate': 140}).rate, 100);
      expect(
        MonthAttendance.fromJson(const {
          'days': [
            {'schoolDay': true},
            'x',
          ],
        }).days,
        isEmpty,
      );
    });
  });

  group('EarlyExitRequest', () {
    test('e2e javobi parse bo`ladi', () {
      final e = EarlyExitRequest.fromJson(const {
        'id': 'e-1',
        'studentId': 'st-1',
        'classId': 'c-1',
        'date': '2026-10-20',
        'time': '12:30',
        'reason': 'Shifokor qabuli',
        'pickupBy': 'Onasi',
        'status': 'PENDING',
        'requestedAt': '2026-10-20T05:00:00.000Z',
        'decidedByStaffId': null,
        'decidedAt': null,
        'studentName': 'Aliyev Vali',
        'className': '7-A',
        'requestedByMe': true,
      });
      expect(e.isPending, isTrue);
      expect(e.time, '12:30');
      expect(e.requestedByMe, isTrue);
      expect(e.requestedAt, isNotNull);
      expect(e.decidedAt, isNull);
      expect(e.decidedByStaffId, isNull);
    });

    test('holatlar; noma`lum → unknown', () {
      expect(EarlyExitStatus.fromApi('APPROVED'), EarlyExitStatus.approved);
      expect(EarlyExitStatus.fromApi('REJECTED'), EarlyExitStatus.rejected);
      expect(EarlyExitStatus.fromApi('CANCELLED'), EarlyExitStatus.unknown);
      expect(EarlyExitStatus.fromApi(null), EarlyExitStatus.unknown);
      final e = EarlyExitRequest.fromJson(const {});
      expect(e.status, EarlyExitStatus.unknown);
      expect(e.requestedByMe, isFalse);
    });
  });
}
