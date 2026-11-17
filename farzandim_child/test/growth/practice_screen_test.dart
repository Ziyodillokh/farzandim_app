// U04 → U06 → U08 mashq oqimi va U07 chiqish tasdig'i (tarmoqsiz soxta manba).
// Soxta manbada savol i ning to'g'ri javobi — (i % 4)-variant.

import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import '../features/learning/learning_fixtures.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

const _profile = LearningProfile(grade: 6, subjects: [Subject.math]);

FakeLearningRepository _repo() =>
    FakeLearningRepository(profile: _profile, clock: () => kG5Now);

Future<void> _pumpPractice(WidgetTester tester, FakeLearningRepository repo) =>
    pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.practice(Subject.math),
      overrides: g5Overrides(learning: repo),
    );

Finder _option(String letter) => find.text(letter);

final _closeButton = find.byWidgetPredicate(
  (w) => w is GIconButton && w.label == 'Yopish',
);

Future<void> _answer(
  WidgetTester tester,
  int questionIndex, {
  required bool correct,
}) async {
  final correctIndex = questionIndex % 4;
  final pick = correct ? correctIndex : (correctIndex + 1) % 4;
  await tester.tap(_option(['A', 'B', 'C', 'D'][pick]));
  await settleG5(tester);
  await tester.tap(find.text('Tekshirish'));
  await settleG5(tester);
}

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('javob tanlanmaguncha «Tekshirish» faol emas', (tester) async {
    await _pumpPractice(tester, _repo());

    expect(find.text('1 + 2 = ?'), findsOneWidget);
    await tester.tap(find.text('Tekshirish'));
    await settleG5(tester);
    // Bosilmadi: hali savol ko'rinishi, tushuntirish yo'q.
    expect(find.text('Barakalla!'), findsNothing);
    expect(find.text('Deyarli topding!'), findsNothing);
  });

  testWidgets(
    'xato javob: qo\'llab-quvvatlovchi tushuntirish va to\'g\'ri javob',
    (tester) async {
      await _pumpPractice(tester, _repo());

      await _answer(tester, 0, correct: false);

      expect(find.text('Deyarli topding!'), findsOneWidget);
      expect(find.text('Sening javobing'), findsOneWidget);
      expect(find.text('Toʻgʻri javob'), findsOneWidget);
      expect(find.text('Keyingi savol'), findsOneWidget);
    },
  );

  testWidgets('10 ta savoldan keyin natija: ball, yulduzlar va DON', (
    tester,
  ) async {
    final repo = _repo();
    await _pumpPractice(tester, repo);

    for (var i = 0; i < 10; i++) {
      await _answer(tester, i, correct: i != 3);
      final action = find.text(i == 9 ? 'Natijani koʻrish' : 'Keyingi savol');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await settleG5(tester);
    }

    expect(find.text('Barakalla!'), findsOneWidget);
    expect(find.text('10 tadan 9 ta toʻgʻri'), findsOneWidget);
    expect(find.text('Birinchi natijang saqlandi'), findsOneWidget);
    expect(find.text('+18 DON'), findsOneWidget);
    expect(find.text('Keyingi mashq'), findsOneWidget);
    expect(repo.results.first.correct, 9);
  });

  testWidgets('natija oldingi safar bilan solishtiriladi', (tester) async {
    final repo = FakeLearningRepository(
      profile: _profile,
      clock: () => kG5Now,
      results: [
        result(Subject.math, 6, kG5Now.subtract(const Duration(days: 4))),
      ],
    );
    await _pumpPractice(tester, repo);

    for (var i = 0; i < 10; i++) {
      await _answer(tester, i, correct: i != 3 && i != 7);
      final action = find.text(i == 9 ? 'Natijani koʻrish' : 'Keyingi savol');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await settleG5(tester);
    }

    expect(
      find.text('Oldingi safardan 2 ta koʻproq toʻgʻri javob'),
      findsOneWidget,
    );
    expect(find.text('Oldingi safar'), findsOneWidget);
    expect(find.text('6/10'), findsOneWidget);
  });

  testWidgets(
    'chiqishda tasdiq: «Davom ettirish» qoldiradi, «Saqlash va chiqish» O\'qishga',
    (tester) async {
      final router = await pumpG5App(
        tester,
        routes: buildGrowthV5Routes(),
        initialLocation: GrowthV5Routes.practice(Subject.math),
        overrides: g5Overrides(learning: _repo()),
      );
      await _answer(tester, 0, correct: true);
      await tester.tap(find.text('Keyingi savol'));
      await settleG5(tester);

      await tester.tap(_closeButton);
      await settleG5(tester);
      expect(find.text('Mashqni toʻxtatasanmi?'), findsOneWidget);
      expect(find.text('1 ta javob saqlandi'), findsOneWidget);

      await tester.tap(find.text('Davom ettirish'));
      await settleG5(tester);
      expect(find.text('Mashqni toʻxtatasanmi?'), findsNothing);

      await tester.tap(_closeButton);
      await settleG5(tester);
      await tester.tap(find.text('Saqlash va chiqish'));
      await settleG5(tester);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        GrowthV5Routes.learn,
      );
    },
  );

  testWidgets('noma\'lum fan havolasi Bugun ekraniga qaytaradi', (
    tester,
  ) async {
    final router = await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: '/mashq/astronomy',
      overrides: g5Overrides(learning: _repo()),
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      GrowthV5Routes.today,
    );
  });

  group('natija hisobi', () {
    test('yulduzlar: 90+ → 3, 70+ → 2, 40+ → 1', () {
      expect(starsFor(9, 10), 3);
      expect(starsFor(8, 10), 2);
      expect(starsFor(4, 10), 1);
      expect(starsFor(3, 10), 0);
      expect(starsFor(0, 0), 0);
    });

    test('oldingi natija bilan solishtirish (o\'z natijasi bilan)', () {
      expect(
        buildOutcome(
          correct: 8,
          total: 10,
          previous: (correct: 6, total: 10),
        ).trend,
        OutcomeTrend.better,
      );
      expect(
        buildOutcome(
          correct: 8,
          total: 10,
          previous: (correct: 6, total: 10),
        ).difference,
        2,
      );
      expect(
        buildOutcome(
          correct: 6,
          total: 10,
          previous: (correct: 6, total: 10),
        ).trend,
        OutcomeTrend.same,
      );
      expect(
        buildOutcome(
          correct: 5,
          total: 10,
          previous: (correct: 6, total: 10),
        ).trend,
        OutcomeTrend.lower,
      );
      expect(buildOutcome(correct: 5, total: 10).trend, OutcomeTrend.first);
    });

    test('mavzular: hammasi to\'g\'ri — kuchli, xato bor — takror', () {
      final outcome = buildOutcome(
        correct: 3,
        total: 4,
        answers: const [
          (topic: 'Kasrlar', isCorrect: true),
          (topic: 'Foizlar', isCorrect: false),
          (topic: 'Kasrlar', isCorrect: true),
          (topic: 'Foizlar', isCorrect: true),
        ],
      );
      expect(outcome.strongTopic, 'Kasrlar');
      expect(outcome.reviewTopic, 'Foizlar');
    });
  });
}
