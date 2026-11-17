// Daily Learning modellari + bosh sahifa raqam formati.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyPlan', () {
    test('jami savollar fanlar bo\'yicha yig\'iladi', () {
      const plan = DailyPlan(
        items: [
          DailyPlanItem(subject: Subject.math, questionCount: 10),
          DailyPlanItem(subject: Subject.english, questionCount: 8),
        ],
      );

      expect(plan.totalQuestions, 18);
      expect(plan.isEmpty, isFalse);
    });

    test('bo\'sh reja — savol yo\'q', () {
      expect(DailyPlan.empty.isEmpty, isTrue);
      expect(DailyPlan.empty.totalQuestions, 0);
    });
  });

  test('natija yo\'q bo\'lsa xulosa kartasi ko\'rsatilmaydi', () {
    expect(LearningSummary.empty.hasResults, isFalse);
    const summary = LearningSummary(
      solvedQuestions: 30,
      averagePercent: 70,
      recentTestCount: 3,
    );
    expect(summary.hasResults, isTrue);
  });

  test('har bir fanning tarjima kaliti subjects.<nom>', () {
    expect(Subject.math.labelKey, 'subjects.math');
    expect(Subject.native.labelKey, 'subjects.native');
  });
}
