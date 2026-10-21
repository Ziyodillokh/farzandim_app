// Maktab UI'sining sof mantig'i: kunlik davomat belgisi, dashboard kartasi
// holati (yashirin / taklif / o'quvchi / moslash) va moslash varag'i
// yordamchilari.

import 'dart:convert';
import 'dart:io';

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter_test/flutter_test.dart';

AttendanceDay _day({required bool schoolDay, String? status, String? inAt}) =>
    AttendanceDay.fromJson({
      'date': '2026-10-20',
      'schoolDay': schoolDay,
      'record': status == null ? null : {'status': status, 'inAt': inAt},
    });

SchoolLinks _links({
  List<Map<String, Object?>> students = const [],
  List<Map<String, Object?>> children = const [
    {'id': 'kid-1', 'name': 'Aziz'},
    {'id': 'kid-2', 'name': 'Laylo'},
  ],
  bool withLink = true,
}) => SchoolLinks.fromJson({
  'links': [
    if (withLink)
      {
        'guardianId': 'g-1',
        'fullName': 'Karimova Malika',
        'relation': 'MOTHER',
        'school': {
          'id': 's-1',
          'name': '12-maktab',
          'shortName': '12-IDUM',
          'city': 'Toshkent',
        },
        'students': students,
      },
  ],
  'children': children,
});

Map<String, Object?> _student(
  String id, {
  String? childId,
  String linkedBy = 'NONE',
}) => {
  'id': id,
  'fullName': 'Karimov $id',
  'className': '7-A',
  'childId': childId,
  'linkedBy': linkedBy,
};

void main() {
  group('SchoolDayStatus.of', () {
    test('kun yo`q → unknown', () {
      expect(SchoolDayStatus.of(null), SchoolDayStatus.unknown);
    });

    test('yozuvsiz o`quv kuni → pending, dam olish kuni → holiday', () {
      expect(
        SchoolDayStatus.of(_day(schoolDay: true)),
        SchoolDayStatus.pending,
      );
      expect(
        SchoolDayStatus.of(_day(schoolDay: false)),
        SchoolDayStatus.holiday,
      );
    });

    test('yozuv holati birma-bir (dam olish kunida ham)', () {
      const cases = {
        'PRESENT': SchoolDayStatus.present,
        'LATE': SchoolDayStatus.late,
        'ABSENT': SchoolDayStatus.absent,
        'LEFT_EARLY': SchoolDayStatus.leftEarly,
        'EXCUSED': SchoolDayStatus.excused,
        'SOMETHING_NEW': SchoolDayStatus.unknown,
      };
      for (final MapEntry(key: raw, value: expected) in cases.entries) {
        expect(
          SchoolDayStatus.of(_day(schoolDay: true, status: raw)),
          expected,
          reason: raw,
        );
      }
      expect(
        SchoolDayStatus.of(_day(schoolDay: false, status: 'PRESENT')),
        SchoolDayStatus.present,
      );
    });

    test('har holat uchun tarjima kaliti uchala tilda bor', () {
      for (final lang in ['uz', 'ru', 'en']) {
        final json =
            jsonDecode(
                  File('assets/translations/$lang.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final status in SchoolDayStatus.values) {
          Object? node = json;
          for (final part in status.labelKey.split('.')) {
            node = node is Map<String, dynamic> ? node[part] : null;
          }
          expect(node, isA<String>(), reason: '$lang: ${status.labelKey}');
        }
      }
    });
  });

  group('SchoolCardMode.of', () {
    test('yuklanmagan yoki bo`lim yo`q → yashirin', () {
      expect(SchoolCardMode.of(null, 'kid-1'), isA<SchoolCardHidden>());
      expect(
        SchoolCardMode.of(SchoolLinks.unavailable, 'kid-1'),
        isA<SchoolCardHidden>(),
      );
    });

    test('bog`lanish yo`q → taklif kodi CTA', () {
      expect(
        SchoolCardMode.of(SchoolLinks.empty, 'kid-1'),
        isA<SchoolCardInvite>(),
      );
      expect(
        SchoolCardMode.of(_links(withLink: false), 'kid-1'),
        isA<SchoolCardInvite>(),
      );
    });

    test('farzandga moslangan o`quvchi → maktabi bilan', () {
      final links = _links(
        students: [
          _student('st-1', childId: 'kid-1', linkedBy: 'ME'),
          _student('st-2'),
        ],
      );
      final mode = SchoolCardMode.of(links, 'kid-1');
      expect(mode, isA<SchoolCardStudent>());
      final student = mode as SchoolCardStudent;
      expect(student.student.id, 'st-1');
      expect(student.school?.displayName, '12-IDUM');
    });

    test('moslanmagan o`quvchilar → moslash taklifi', () {
      final links = _links(
        students: [
          _student('st-1', childId: 'kid-1', linkedBy: 'ME'),
          _student('st-2'),
          _student('st-3', linkedBy: 'OTHER'),
        ],
      );
      final mode = SchoolCardMode.of(links, 'kid-2');
      expect(mode, isA<SchoolCardMatch>());
      final match = mode as SchoolCardMatch;
      expect(match.students.map((s) => s.id), ['st-2']);
      expect(match.links, links);
    });

    test('moslaydigan o`quvchi yo`q (boshqa farzand / OTHER) → yashirin', () {
      final links = _links(
        students: [
          _student('st-1', childId: 'kid-1', linkedBy: 'ME'),
          _student('st-3', linkedBy: 'OTHER'),
        ],
      );
      expect(SchoolCardMode.of(links, 'kid-2'), isA<SchoolCardHidden>());
    });
  });

  group('moslash varag`i yordamchilari', () {
    test('studentsByOtherChild — o`quvchining o`zi chiqarib tashlanadi', () {
      final links = _links(
        students: [
          _student('st-1', childId: 'kid-1', linkedBy: 'ME'),
          _student('st-2', childId: 'kid-2', linkedBy: 'ME'),
          _student('st-3'),
        ],
      );
      final map = studentsByOtherChild(links, 'st-1');
      expect(map.keys, ['kid-2']);
      expect(map['kid-2']?.id, 'st-2');
      expect(studentsByOtherChild(links, 'st-3').keys, ['kid-1', 'kid-2']);
    });

    test('mergeMatchChildren — ilova ro`yxati oldin, takror yo`q', () {
      const fromApp = [
        ChildRef(id: 'kid-3', name: 'Yangi'),
        ChildRef(id: 'kid-1', name: 'Aziz (ilova)'),
      ];
      const fromLinks = [
        ChildRef(id: 'kid-1', name: 'Aziz'),
        ChildRef(id: 'kid-2', name: 'Laylo'),
        ChildRef(id: '', name: 'id`siz'),
      ];
      final merged = mergeMatchChildren(fromApp, fromLinks);
      expect(merged.map((c) => c.id), ['kid-3', 'kid-1', 'kid-2']);
      expect(merged[1].name, 'Aziz (ilova)');
      expect(mergeMatchChildren(const [], const []), isEmpty);
    });
  });
}
