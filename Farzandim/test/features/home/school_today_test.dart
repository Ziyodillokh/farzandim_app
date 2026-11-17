// Maktab tabi «Bugun»: har o'quvchining bugungi holati (rang + matn) va
// kirish / chiqish vaqti; karta bosilsa — o'sha o'quvchi.

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/school_today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _school = SchoolInfo(
  id: 'sc-1',
  name: '24-maktab',
  shortName: '24-maktab',
  city: 'Toshkent',
);

SchoolLinks _links() => SchoolLinks(
  links: [
    SchoolLink(
      guardianId: 'g-1',
      fullName: 'Nilufar Karimova',
      relation: GuardianRelation.values.first,
      school: _school,
      students: const [
        LinkedStudent(
          id: 'st-1',
          fullName: 'Aziza Karimova',
          className: '6-B',
          linkedBy: LinkedBy.me,
          childId: 'kid-1',
        ),
        LinkedStudent(
          id: 'st-2',
          fullName: 'Jasur Karimov',
          className: '2-A',
          linkedBy: LinkedBy.none,
        ),
      ],
    ),
  ],
  children: const [],
);

void main() {
  testWidgets('holat, vaqt va tanlash', (tester) async {
    LinkedStudent? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayAttendanceProvider.overrideWith(
            (ref, id) => AsyncData(
              id == 'st-1'
                  ? const AttendanceDay(
                      date: '2026-11-09',
                      schoolDay: true,
                      record: AttendanceRecord(
                        status: AttendanceStatus.present,
                        inAt: '08:12',
                      ),
                    )
                  : const AttendanceDay(date: '2026-11-09', schoolDay: true),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchoolTodayStudents(
                links: _links(),
                onOpen: (s) => opened = s,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text(SchoolDayStatus.present.labelKey), findsOneWidget);
    expect(find.text('08:12'), findsOneWidget);
    // Hali belgilanmagan o'quvchi — kulrang holat.
    expect(find.text(SchoolDayStatus.pending.labelKey), findsOneWidget);

    await tester.tap(find.text('Jasur Karimov'));
    expect(opened?.id, 'st-2');
  });

  test('holat ranglari', () {
    expect(schoolDayColor(SchoolDayStatus.present), const Color(0xFF22C55E));
    expect(schoolDayColor(SchoolDayStatus.absent), const Color(0xFFFF5A5D));
    expect(
      schoolDayColor(SchoolDayStatus.late),
      schoolDayColor(SchoolDayStatus.leftEarly),
    );
  });
}
