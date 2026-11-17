// Maktab tabi «Bo'limlar» (P02): to'lov kuni o'tgan eslatma — qizil
// «To'lanmagan» plitasi; davomat — bugun kelganlar soni; «Bog'lanish» —
// yangi javoblar. «Maktablar» qatori yig'iq, bosilsa ochiladi; e'tibor
// talab qiladigan maktab (moslanmagan o'quvchi) ochiq turadi.

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/school_link_card.dart';
import 'package:farzandim/features/school/presentation/widgets/school_section_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _school = SchoolInfo(
  id: 'sc-1',
  name: '24-maktab',
  shortName: '24-maktab',
  city: 'Toshkent',
);

const _aziza = LinkedStudent(
  id: 'st-1',
  fullName: 'Aziza Karimova',
  className: '6-B',
  linkedBy: LinkedBy.me,
  childId: 'kid-1',
);

const _jasur = LinkedStudent(
  id: 'st-2',
  fullName: 'Jasur Karimov',
  className: '2-A',
  linkedBy: LinkedBy.me,
  childId: 'kid-2',
);

SchoolLink _link(List<LinkedStudent> students) => SchoolLink(
  guardianId: 'g-1',
  fullName: 'Nilufar Karimova',
  relation: GuardianRelation.values.first,
  school: _school,
  students: students,
);

String _isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

SchoolPaymentReminder _overdue() => SchoolPaymentReminder(
  id: 'p-1',
  schoolId: 'sc-1',
  schoolName: '24-maktab',
  nextDate: _isoDay(DateTime.now().subtract(const Duration(days: 3))),
  prepaidMonths: 0,
  paused: false,
  children: const [],
  openVerification: false,
);

Future<void> _pumpTiles(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: SchoolSectionTiles(
              students: const [_aziza, _jasur],
              onAttendance: () {},
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.schoolContacts,
        builder: (_, _) => const Text('contacts-page'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        schoolPaymentsProvider.overrideWith((ref) async => [_overdue()]),
        schoolUnreadCountProvider.overrideWith((ref) async => 2),
        schoolThreadsUnreadProvider.overrideWith((ref) => 1),
        todayAttendanceProvider.overrideWith(
          (ref, id) => AsyncData(
            AttendanceDay(
              date: '2026-11-09',
              schoolDay: true,
              record: id == 'st-1'
                  ? const AttendanceRecord(
                      status: AttendanceStatus.present,
                      inAt: '08:12',
                    )
                  : null,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('to`lov kuni o`tgan — qizil «To`lanmagan» va son', (
    tester,
  ) async {
    await _pumpTiles(tester);

    expect(find.text('school.home.tiles.paymentsDue'), findsOneWidget);
    expect(
      find.bySemanticsLabel('school.home.tiles.paymentsDueA11y'),
      findsOneWidget,
    );
    expect(find.text('1'), findsNWidgets(2)); // to'lov + yangi javob
    expect(find.text('2'), findsOneWidget); // e'lonlar
    expect(find.text('school.home.tiles.attendanceToday'), findsOneWidget);
    expect(find.text('school.connect.newReplies'), findsOneWidget);
  });

  testWidgets('«Bog`lanish» — maktab bilan bog`lanish sahifasi', (
    tester,
  ) async {
    await _pumpTiles(tester);
    await tester.tap(find.text('school.home.tiles.contact'));
    await tester.pumpAndSettle();
    expect(find.text('contacts-page'), findsOneWidget);
  });

  group('SchoolLinkCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required SchoolLink link,
      required bool expanded,
      required VoidCallback onToggle,
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayAttendanceProvider.overrideWith(
            (ref, id) => const AsyncData(null),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchoolLinkCard(
                link: link,
                children: const [],
                expanded: expanded,
                onToggle: onToggle,
                onOpenStudent: (_) {},
                onMatch: (_) {},
                onUnlink: () {},
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('yig`iq: shahar va farzandlar soni; bosilsa onToggle', (
      tester,
    ) async {
      var toggled = 0;
      await pumpCard(
        tester,
        link: _link(const [_aziza, _jasur]),
        expanded: false,
        onToggle: () => toggled++,
      );

      expect(find.text('24-maktab'), findsOneWidget);
      expect(find.text('Toshkent · school.home.schoolKids'), findsOneWidget);
      expect(find.text('school.home.unlink'), findsNothing);
      expect(find.text('Aziza Karimova'), findsNothing);

      await tester.tap(find.text('24-maktab'));
      expect(toggled, 1);
    });

    testWidgets('ochiq: o`quvchilar va «Aloqani uzish»', (tester) async {
      await pumpCard(
        tester,
        link: _link(const [_aziza]),
        expanded: true,
        onToggle: () {},
      );

      expect(find.text('Aziza Karimova'), findsOneWidget);
      expect(find.text('school.home.unlink'), findsOneWidget);
    });

    test('e`tibor talab qiladi: tasdiq, o`quvchisiz, moslanmagan', () {
      expect(schoolLinkNeedsAttention(_link(const [_aziza, _jasur])), isFalse);
      expect(schoolLinkNeedsAttention(_link(const [])), isTrue);
      expect(
        schoolLinkNeedsAttention(
          _link(const [
            LinkedStudent(
              id: 'st-3',
              fullName: 'Bobur',
              className: '1-A',
              linkedBy: LinkedBy.none,
            ),
          ]),
        ),
        isTrue,
      );
      final pending = SchoolLink(
        guardianId: 'g-2',
        fullName: 'Nilufar Karimova',
        relation: GuardianRelation.values.first,
        school: _school,
        students: const [_aziza],
        pendingReview: true,
      );
      expect(schoolLinkNeedsAttention(pending), isTrue);
    });
  });
}
