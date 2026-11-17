// Maktab tugmalari ekran o'quvchiga "tugma" bo'lib ko'rinadi; dashboard
// kartasidagi o'qilmagan e'lonlar belgisi kamida 48x48 bosish maydoniga ega.

import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/school_dashboard_card.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _links = SchoolLinks.fromJson(const {
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

void main() {
  testWidgets('matnli tugma — ekran o`quvchiga tugma', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolTextButton(label: 'Bekor qilish', onTap: () => taps++),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(SchoolTextButton)),
      matchesSemantics(
        label: 'Bekor qilish',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Bekor qilish'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('o`qilmagan e`lonlar belgisi — 48x48 bosish maydoni', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolLinksProvider.overrideWith((ref) async => _links),
          schoolUnreadCountProvider.overrideWith((ref) async => 3),
          todayAttendanceProvider.overrideWith(
            (ref, id) => const AsyncValue.loading(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SchoolDashboardCard(childId: 'kid-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.bySemanticsLabel(RegExp('dashboard.school.unread'));
    expect(badge, findsOneWidget);
    final size = tester.getSize(badge);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
