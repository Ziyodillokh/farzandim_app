// Natijalardan hisoblanadigan ko'rsatkichlar (reja, xulosa, haftalik
// o'sish, fanlar, ketma-ketlik).

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'learning_fixtures.dart';

final _now = DateTime(2026, 10, 15, 18);
DateTime _daysAgo(int d, [int hour = 17]) =>
    DateTime(_now.year, _now.month, _now.day - d, hour);

void main() {
  group('buildDailyPlan', () {
    const profile = LearningProfile(
      grade: 7,
      subjects: [Subject.math, Subject.english],
    );

    test('profil yo\'q — bo\'sh reja', () {
      expect(buildDailyPlan(null, const [], _now).isEmpty, isTrue);
    });

    test('faqat BUGUNGI natijalar bajarilgan deb belgilanadi', () {
      final plan = buildDailyPlan(profile, [
        result(Subject.math, 9, _daysAgo(0, 9)),
        result(Subject.english, 4, _daysAgo(1)),
      ], _now);

      expect(plan.items.map((i) => i.subject), [Subject.math, Subject.english]);
      expect(plan.items.first.isDone, isTrue);
      expect(plan.items.last.isDone, isFalse);
      expect(plan.doneCount, 1);
      expect(plan.isComplete, isFalse);
      expect(plan.nextItem?.subject, Subject.english);
      expect(plan.totalQuestions, kDailyQuestionCount * 2);
    });

    test('hammasi yechilsa — reja yakunlangan, navbatdagi yo\'q', () {
      final plan = buildDailyPlan(profile, [
        result(Subject.math, 9, _daysAgo(0, 9)),
        result(Subject.english, 7, _daysAgo(0, 10)),
      ], _now);
      expect(plan.isComplete, isTrue);
      expect(plan.nextItem, isNull);
    });
  });

  test('percentOf — jami to\'g\'ri / jami savol', () {
    expect(percentOf(const []), isNull);
    expect(
      percentOf([
        result(Subject.math, 9, _now),
        result(Subject.math, 2, _now, total: 5),
      ]),
      73,
    );
  });

  group('subjectScores', () {
    test('profil tartibi birinchi, natijasizlar tushib qoladi', () {
      final scores = subjectScores(
        [
          result(Subject.history, 6, _daysAgo(0)),
          result(Subject.math, 8, _daysAgo(1)),
        ],
        order: const [Subject.math, Subject.english],
      );
      expect(scores.map((s) => (s.subject, s.percent)), [
        (Subject.math, 80),
        (Subject.history, 60),
      ]);
    });

    test('faqat so\'nggi $kSubjectWindow ta natija hisoblanadi', () {
      final results = [
        for (var i = 0; i < kSubjectWindow; i++)
          result(Subject.math, 10, _daysAgo(i)),
        result(Subject.math, 0, _daysAgo(9)),
      ];
      expect(subjectScores(results).single.percent, 100);
    });
  });

  group('summarize', () {
    test('natija yo\'q — bo\'sh xulosa', () {
      expect(summarize(const []).hasResults, isFalse);
    });

    test('kuchli va e\'tibor talab fan, jami savollar', () {
      final summary = summarize([
        result(Subject.math, 9, _daysAgo(0)),
        result(Subject.english, 5, _daysAgo(1)),
        result(Subject.native, 7, _daysAgo(2)),
      ]);
      expect(summary.solvedQuestions, 30);
      expect(summary.averagePercent, 70);
      expect(summary.recentTestCount, 3);
      expect(summary.strongSubject, Subject.math);
      expect(summary.strongPercent, 90);
      expect(summary.focusSubject, Subject.english);
    });

    test('bitta fan — tavsiya qilinadigan boshqa fan yo\'q', () {
      final summary = summarize([result(Subject.math, 9, _daysAgo(0))]);
      expect(summary.strongSubject, Subject.math);
      expect(summary.focusSubject, isNull);
    });
  });

  group('weeklyProgress', () {
    test('natija yo\'q — null', () {
      expect(weeklyProgress(const [], _now), isNull);
    });

    test('bu hafta va o\'tgan hafta solishtiriladi', () {
      final progress = weeklyProgress([
        result(Subject.math, 9, _daysAgo(0)),
        result(Subject.math, 7, _daysAgo(6)),
        result(Subject.math, 6, _daysAgo(7)),
        result(Subject.math, 6, _daysAgo(13)),
        result(Subject.math, 1, _daysAgo(14)),
      ], _now)!;

      expect(progress.testsThisWeek, 2);
      expect(progress.correctAnswers, 16);
      expect(progress.overallPercent, 80);
      expect(progress.growthPercent, 20);
      expect(progress.successStreak, 1);
    });

    test('bu hafta natija yo\'q — umumiy so\'nggi testlardan, o\'sish 0', () {
      final progress = weeklyProgress([
        result(Subject.math, 6, _daysAgo(10)),
      ], _now)!;
      expect(progress.testsThisWeek, 0);
      expect(progress.overallPercent, 60);
      expect(progress.growthPercent, 0);
      expect(progress.successStreak, 0);
    });
  });

  group('learningStreak', () {
    test('bugundan orqaga uzluksiz kunlar', () {
      expect(
        learningStreak([
          result(Subject.math, 5, _daysAgo(0)),
          result(Subject.math, 5, _daysAgo(1)),
          result(Subject.english, 5, _daysAgo(1, 9)),
          result(Subject.math, 5, _daysAgo(2)),
          result(Subject.math, 5, _daysAgo(4)),
        ], _now),
        3,
      );
    });

    test('bugun hali yechilmagan bo\'lsa — kechadan sanaladi', () {
      expect(
        learningStreak([
          result(Subject.math, 5, _daysAgo(1)),
          result(Subject.math, 5, _daysAgo(2)),
        ], _now),
        2,
      );
      expect(learningStreak([result(Subject.math, 5, _daysAgo(2))], _now), 0);
    });
  });

  test('recommendation — eng past fan', () {
    final tip = recommendation(
      subjectScores([
        result(Subject.math, 9, _daysAgo(0)),
        result(Subject.english, 4, _daysAgo(0)),
      ]),
    );
    expect(tip?.subject, Subject.english);
    expect(recommendation(const []), isNull);
  });
}
