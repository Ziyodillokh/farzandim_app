// Rivojlanish — natija darajalari, foiz va tavsiya mantig'i.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/progress_providers.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/subject_score_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TestResult _result(int correct, int total) => TestResult(
  id: 'x',
  subject: Subject.math,
  topic: 'Kasrlar',
  correct: correct,
  total: total,
  date: DateTime(2026, 10, 15),
);

void main() {
  group('ScoreLevel', () {
    test('≥80% yaxshi, 60–79% o\'rta, <60% past', () {
      expect(ScoreLevel.of(8, 10), ScoreLevel.good);
      expect(ScoreLevel.of(9, 10), ScoreLevel.good);
      expect(ScoreLevel.of(7, 10), ScoreLevel.medium);
      expect(ScoreLevel.of(6, 10), ScoreLevel.medium);
      expect(ScoreLevel.of(5, 10), ScoreLevel.low);
    });

    test('savol yo\'q — past (0 ga bo\'linmaydi)', () {
      expect(ScoreLevel.of(0, 0), ScoreLevel.low);
      expect(_result(0, 0).percent, 0);
    });
  });

  test('foiz yaxlitlanadi', () {
    expect(_result(9, 10).percent, 90);
    expect(_result(2, 3).percent, 67);
  });

  test('tavsiya — eng past natijali fan', () {
    final container = ProviderContainer(
      overrides: [
        subjectScoresProvider.overrideWithValue(const [
          SubjectScore(subject: Subject.math, percent: 92),
          SubjectScore(subject: Subject.english, percent: 65),
          SubjectScore(subject: Subject.native, percent: 78),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final tip = container.read(progressRecommendationProvider);
    expect(tip?.subject, Subject.english);
    expect(tip?.testCount, 10);
  });

  test('fan natijasi bo\'lmasa tavsiya yo\'q', () {
    final container = ProviderContainer(
      overrides: [subjectScoresProvider.overrideWithValue(const [])],
    );
    addTearDown(container.dispose);

    expect(container.read(progressRecommendationProvider), isNull);
  });

  group('fitTileWidths', () {
    test(
      'keng ekranda — matnga mos (proporsional), jami kenglik saqlanadi',
      () {
        final w = fitTileWidths([120, 110, 100], 330);
        expect(w[0], greaterThan(w[1]));
        expect(w[1], greaterThan(w[2]));
        expect(w.reduce((a, b) => a + b), closeTo(330, 0.001));
      },
    );

    test('tor ekranda biror plitka juda torayadi — teng kengliklar', () {
      final w = fitTileWidths([80, 95, 130], 255);
      expect(w, everyElement(closeTo(85, 0.001)));
    });

    test('bo\'sh ro\'yxat — bo\'sh natija', () {
      expect(fitTileWidths([], 300), isEmpty);
    });
  });
}
