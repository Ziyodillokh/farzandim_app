// Growth (ota-ona) modellari: backend `learning.e2e-spec` javoblari shakli,
// fanlar va sinf qoidalari (backend `subjects.ts` bilan bir xil), noma'lum
// qiymatlar va buzuq maydonlar — parse hech qachon otmaydi.

import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningSubject', () {
    test('API nomidan; noma`lum → unknown', () {
      expect(LearningSubject.fromApi('math'), LearningSubject.math);
      expect(
        LearningSubject.fromApi('informatics'),
        LearningSubject.informatics,
      );
      expect(LearningSubject.fromApi('astrology'), LearningSubject.unknown);
      expect(LearningSubject.fromApi('unknown'), LearningSubject.unknown);
      expect(LearningSubject.fromApi(null), LearningSubject.unknown);
      expect(LearningSubject.fromApi(7), LearningSubject.unknown);
    });

    test('sinf qoidasi: tarix/biologiya/geografiya/informatika 5, fizika 6, '
        'kimyo 7', () {
      expect(LearningSubject.forGrade(1), [
        LearningSubject.math,
        LearningSubject.english,
        LearningSubject.native,
        LearningSubject.russian,
      ]);
      final grade5 = LearningSubject.forGrade(5);
      expect(grade5, contains(LearningSubject.history));
      expect(grade5, contains(LearningSubject.informatics));
      expect(grade5, isNot(contains(LearningSubject.physics)));
      expect(LearningSubject.forGrade(6), contains(LearningSubject.physics));
      expect(
        LearningSubject.forGrade(6),
        isNot(contains(LearningSubject.chemistry)),
      );
      expect(LearningSubject.forGrade(11), hasLength(10));
      expect(LearningSubject.unknown.isTaughtIn(11), isFalse);
    });

    test('tarjima kaliti', () {
      expect(LearningSubject.math.labelKey, 'growth.subjects.math');
      expect(LearningSubject.unknown.labelKey, 'growth.subjects.unknown');
    });
  });

  group('LearningProfile', () {
    test('parse va toJson', () {
      final profile = LearningProfile.tryParse({
        'grade': 8,
        'subjects': ['physics', 'math'],
        'updatedAt': '2026-10-19T08:00:00.000Z',
      })!;
      expect(profile.grade, 8);
      expect(profile.subjects, [LearningSubject.physics, LearningSubject.math]);
      expect(profile.updatedAt, isNotNull);
      expect(profile.isValid, isTrue);
      expect(profile.toJson(), {
        'grade': 8,
        'subjects': ['physics', 'math'],
      });
    });

    test('null, obyekt emas yoki sinfsiz → null', () {
      expect(LearningProfile.tryParse(null), isNull);
      expect(LearningProfile.tryParse('7-sinf'), isNull);
      expect(LearningProfile.tryParse({'subjects': <String>[]}), isNull);
    });

    test('noma`lum fan saqlanadi, lekin yuborilmaydi va yaroqsiz', () {
      final profile = LearningProfile.tryParse({
        'grade': 7,
        'subjects': ['math', 'astrology', 'math', 42],
      })!;
      expect(profile.subjects, [LearningSubject.math, LearningSubject.unknown]);
      expect(profile.isValid, isFalse);
      expect(profile.toJson(), {
        'grade': 7,
        'subjects': ['math'],
      });
    });

    test('backend qoidalari (isValid)', () {
      LearningProfile p(int grade, List<LearningSubject> subjects) =>
          LearningProfile(grade: grade, subjects: subjects);
      expect(p(7, [LearningSubject.math]).isValid, isTrue);
      expect(p(0, [LearningSubject.math]).isValid, isFalse);
      expect(p(12, [LearningSubject.math]).isValid, isFalse);
      expect(p(7, []).isValid, isFalse);
      expect(p(5, [LearningSubject.physics]).isValid, isFalse);
      expect(
        p(7, [LearningSubject.math, LearningSubject.math]).isValid,
        isFalse,
      );
      expect(
        p(9, [
          LearningSubject.math,
          LearningSubject.english,
          LearningSubject.native,
          LearningSubject.history,
          LearningSubject.biology,
          LearningSubject.physics,
        ]).isValid,
        isFalse,
        reason: '5 tadan ortiq fan',
      );
    });
  });

  group('LearningSummary', () {
    test('e2e javobi (2 test, 70%) parse bo`ladi', () {
      final summary = LearningSummary.fromJson(const {
        'profile': {
          'grade': 7,
          'subjects': ['math', 'english', 'native'],
        },
        'from': '2026-10-14',
        'to': '2026-10-20',
        'periodDays': 7,
        'testsCount': 2,
        'correctAnswers': 14,
        'totalAnswers': 20,
        'overallPercent': 70,
        'previousPercent': 60,
        'growthPercent': 10,
        'subjects': [
          {'subject': 'math', 'percent': 90, 'tests': 1},
          {'subject': 'english', 'percent': 50, 'tests': 1},
          {'subject': 'art', 'percent': 80, 'tests': 1},
        ],
        'strongSubject': 'math',
        'focusSubject': 'english',
        'activeDays': 1,
        'streakDays': 1,
      });
      expect(summary.hasTests, isTrue);
      expect(summary.profile?.grade, 7);
      expect(summary.profile?.subjects, hasLength(3));
      expect(summary.from, '2026-10-14');
      expect(summary.periodDays, 7);
      expect(summary.correctAnswers, 14);
      expect(summary.overallPercent, 70);
      expect(summary.growthPercent, 10);
      expect(summary.subjects.first.subject, LearningSubject.math);
      expect(summary.subjects.first.percent, 90);
      expect(summary.subjects.last.subject, LearningSubject.unknown);
      expect(summary.strongSubject, LearningSubject.math);
      expect(summary.focusSubject, LearningSubject.english);
      expect(summary.streakDays, 1);
    });

    test('test yo`q: null foizlar va fanlar, salbiy o`sish ham bo`ladi', () {
      final empty = LearningSummary.fromJson(const {
        'profile': null,
        'periodDays': 30,
        'testsCount': 0,
        'overallPercent': null,
        'previousPercent': null,
        'growthPercent': null,
        'subjects': <Object>[],
        'strongSubject': null,
        'focusSubject': null,
      });
      expect(empty.hasTests, isFalse);
      expect(empty.profile, isNull);
      expect(empty.periodDays, 30);
      expect(empty.overallPercent, isNull);
      expect(empty.strongSubject, isNull);
      expect(empty.focusSubject, isNull);

      expect(
        LearningSummary.fromJson(const {'growthPercent': -15}).growthPercent,
        -15,
      );
    });

    test('bo`sh javob — standart qiymatlar', () {
      final summary = LearningSummary.fromJson(const {});
      expect(summary.periodDays, 7);
      expect(summary.testsCount, 0);
      expect(summary.subjects, isEmpty);
      expect(summary.strongSubject, isNull);
    });
  });

  group('LearningResultsPage', () {
    test('natijalar va kursor', () {
      final page = LearningResultsPage.fromJson(const {
        'items': [
          {
            'id': 'r-1',
            'subject': 'math',
            'topic': {'uz': 'Kasrlar', 'ru': 'Дроби', 'en': 'Fractions'},
            'correct': 9,
            'total': 10,
            'percent': 90,
            'isDaily': true,
            'xpEarned': 45,
            'donEarned': 5,
            'date': '2026-10-20T06:00:00.000Z',
            'durationSeconds': 312,
          },
          {'id': 'r-2', 'subject': 'chess', 'topic': null},
          'buzuq',
          {'subject': 'math'},
        ],
        'nextBefore': '2026-10-19T06:00:00.000Z',
      });
      expect(page.items.map((r) => r.id), ['r-1', 'r-2']);
      expect(page.hasMore, isTrue);
      expect(page.nextBefore, '2026-10-19T06:00:00.000Z');

      final first = page.items.first;
      expect(first.subject, LearningSubject.math);
      expect(first.topic?.of('ru'), 'Дроби');
      expect(first.correct, 9);
      expect(first.percent, 90);
      expect(first.isDaily, isTrue);
      expect(first.donEarned, 5);
      expect(first.date, DateTime.utc(2026, 10, 20, 6).toLocal());
      expect(first.durationSeconds, 312);

      final second = page.items.last;
      expect(second.subject, LearningSubject.unknown);
      expect(second.topic, isNull);
      expect(second.date, isNull);
    });

    test('oxirgi sahifa va bo`sh javob', () {
      expect(LearningResultsPage.fromJson(const {}).hasMore, isFalse);
      expect(LearningResultsPage.fromJson(const {}).items, isEmpty);
      expect(
        LearningResultsPage.fromJson(const {
          'items': <Object>[],
          'nextBefore': null,
        }).hasMore,
        isFalse,
      );
    });
  });

  group('LocalizedText', () {
    test('kerakli til yo`q → o`zbekcha, u ham yo`q → birinchisi', () {
      final text = LocalizedText.tryParse({
        'uz': 'Kasrlar',
        'en': 'Fractions',
      })!;
      expect(text.of('en'), 'Fractions');
      expect(text.of('ru'), 'Kasrlar');
      expect(LocalizedText.tryParse({'en': 'Only'})!.of('ru'), 'Only');
    });

    test('satr, bo`sh va noto`g`ri qiymatlar', () {
      expect(LocalizedText.tryParse('Kasrlar')!.of('ru'), 'Kasrlar');
      expect(LocalizedText.tryParse(''), isNull);
      expect(LocalizedText.tryParse({'uz': 5, 'ru': ''}), isNull);
      expect(LocalizedText.tryParse(42), isNull);
    });
  });
}
