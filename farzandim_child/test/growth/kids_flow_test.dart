// 1–4-sinf oqimi: B03 bosh ekran, U05 savol (javob shu ekranda tekshiriladi)
// va U20 natija. Soxta manbada savol i ning to'g'ri javobi — (i % 4)-variant.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/growth/bugun/kids_today_screen.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

const _profile = LearningProfile(
  grade: 2,
  subjects: [Subject.native, Subject.math],
);

FakeLearningRepository _repo() =>
    FakeLearningRepository(profile: _profile, clock: () => kG5Now);

Future<void> _pump(WidgetTester tester, String location) => pumpG5App(
  tester,
  routes: buildGrowthV5Routes(),
  initialLocation: location,
  overrides: g5Overrides(learning: _repo(), childName: 'Jasur Karimov'),
);

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('B03: 2-sinf o\'quvchisiga soddalashtirilgan bosh ekran', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.today);

    expect(find.byType(KidsTodayView), findsOneWidget);
    expect(find.text('Salom, Jasur!'), findsOneWidget);
    expect(find.text('2-sinf'), findsOneWidget);
    expect(find.text('Bugungi oʻyin-mashq'), findsOneWidget);
    expect(find.text('Yana 2 ta oʻyin qoldi'), findsOneWidget);

    await tester.tap(find.text('Boshlash'));
    await settleG5(tester);
    expect(
      tester.widget<PracticeScreen>(find.byType(PracticeScreen)).subject,
      Subject.native,
    );
  });

  testWidgets('U05: javob shu ekranda tekshiriladi, xatoda uyaltirmaydi', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.practice(Subject.math));

    // Savol 0: to'g'ri javob A — B ni tanlaymiz (xato).
    await tester.tap(find.bySemanticsLabel('B variant: 4'));
    await settleG5(tester);
    await tester.tap(find.text('Tekshirish'));
    await settleG5(tester);

    expect(find.text('Keling, birga oʻylaymiz'), findsOneWidget);
    expect(find.text('Toʻgʻri javob: 3'), findsOneWidget);
    expect(find.text('Keyingi savol'), findsOneWidget);
  });

  testWidgets('U20: oxirida yulduzli natija va «Bosh sahifaga»', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.practice(Subject.math));

    for (var i = 0; i < 10; i++) {
      // Variant plitasida harf ko'rinmaydi — to'g'ri variantni semantik nom bilan tanlaymiz.
      final options = find.bySemanticsLabel(
        RegExp('^${['A', 'B', 'C', 'D'][i % 4]} variant'),
      );
      await tester.tap(options);
      await settleG5(tester);
      await tester.tap(find.text('Tekshirish'));
      await settleG5(tester);
      await tester.tap(
        find.text(i == 9 ? 'Natijani koʻrish' : 'Keyingi savol'),
      );
      await settleG5(tester);
    }

    expect(find.text('Barakalla, Jasur!'), findsOneWidget);
    expect(find.text('10 tadan 10 ta toʻgʻri'), findsOneWidget);
    expect(find.bySemanticsLabel('5 yulduzdan 5 tasi'), findsOneWidget);
    expect(find.text('Bosh sahifaga'), findsOneWidget);
  });
}
