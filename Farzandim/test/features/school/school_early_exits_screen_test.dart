// Erta ketish ekrani: bog'lanishlar ro'yxati avval yuklanmagan bo'lsa
// (tarmoq xatosi) "Yangi so'rov" yashirin; pastga tortib yangilash uni ham
// qayta so'raydi va tugma qaytadi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/screens/school_early_exits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  /// Shuncha `fetchLinks` tarmoq xatosi bilan yiqiladi.
  int failLinks = 1;
  int linkFetches = 0;

  @override
  Future<SchoolLinks> fetchLinks() async {
    linkFetches++;
    if (failLinks > 0) {
      failLinks--;
      throw const SchoolFailure(SchoolFailureKind.network);
    }
    return SchoolLinks.fromJson(const {
      'links': [
        {
          'guardianId': 'g-1',
          'school': {'id': 's-1', 'name': 'Test maktab'},
          'students': [
            {
              'id': 'st-1',
              'fullName': 'Karimov Aziz',
              'className': '7-A',
              'childId': 'kid-1',
              'linkedBy': 'ME',
            },
          ],
        },
      ],
      'children': [
        {'id': 'kid-1', 'name': 'Aziz'},
      ],
    });
  }

  @override
  Future<List<EarlyExitRequest>> fetchEarlyExits() async => [
    EarlyExitRequest.fromJson(const {
      'id': 'e-1',
      'studentId': 'st-1',
      'date': '2026-10-20',
      'time': '13:30',
      'reason': 'Shifokor',
      'pickupBy': 'Onasi',
      'status': 'PENDING',
      'studentName': 'Karimov Aziz',
      'requestedByMe': true,
    }),
  ];
}

void main() {
  testWidgets(
    'bog`lanishlar xatosidan keyin tortib yangilash tugmani qaytaradi',
    (tester) async {
      final repo = _FakeSchoolRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolRepositoryProvider.overrideWithValue(repo),
            schoolSignedInProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(home: SchoolEarlyExitsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final newRequest = find.text('school.earlyExit.new');
      expect(find.text('Karimov Aziz'), findsWidgets);
      expect(newRequest, findsNothing);
      expect(repo.linkFetches, 1);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
      await tester.pumpAndSettle();

      expect(repo.linkFetches, 2);
      expect(newRequest, findsOneWidget);
    },
  );
}
