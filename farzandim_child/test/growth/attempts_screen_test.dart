// U09 · Urinishlar tarixi va undan ochiladigan natija (U08).

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import '../features/learning/learning_fixtures.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

void main() {
  setUpAll(setUpG5WidgetTests);

  Future<void> pump(WidgetTester tester, {bool empty = false}) => pumpG5App(
    tester,
    routes: buildGrowthV5Routes(),
    initialLocation: GrowthV5Routes.attempts,
    overrides: g5Overrides(
      learning: FakeLearningRepository(
        profile: const LearningProfile(grade: 6, subjects: [Subject.math]),
        clock: () => kG5Now,
        results: empty
            ? const []
            : [
                result(
                  Subject.math,
                  8,
                  kG5Now.subtract(const Duration(hours: 2)),
                  id: 'r2',
                ),
                result(
                  Subject.math,
                  6,
                  DateTime(2026, 11, 1, 10),
                  id: 'r1',
                  isDaily: false,
                ),
              ],
      ),
    ),
  );

  testWidgets('natijalar: ball, sana va holat', (tester) async {
    await pump(tester);

    expect(find.text('5-noyabr'), findsOneWidget);
    expect(find.text('1-noyabr'), findsOneWidget);
    expect(find.text('Tasdiqlandi'), findsOneWidget);
    expect(find.text('Qoʻshimcha mashq'), findsOneWidget);
  });

  testWidgets('qator bosilsa natija oldingisi bilan solishtiriladi', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('5-noyabr'));
    await settleG5(tester);

    expect(find.text('10 tadan 8 ta toʻgʻri'), findsOneWidget);
    expect(
      find.text('Oldingi safardan 2 ta koʻproq toʻgʻri javob'),
      findsOneWidget,
    );
  });

  testWidgets('urinish yo\'q: mashqni boshlash taklifi', (tester) async {
    await pump(tester, empty: true);

    expect(
      find.text('Hali urinish yoʻq. Birinchi mashqni boshla!'),
      findsOneWidget,
    );
  });
}
