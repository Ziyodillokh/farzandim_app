// Model JSON'i: profil, server natijasi, urinish va tahlil.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningProfile', () {
    test('JSON orqali tiklanadi', () {
      const profile = LearningProfile(
        grade: 8,
        subjects: [Subject.physics, Subject.math],
      );
      final restored = LearningProfile.tryFromJson(profile.toJson())!;
      expect(restored.grade, 8);
      expect(restored.subjects, [Subject.physics, Subject.math]);
    });

    test('noto\'g\'ri profil rad etiladi', () {
      expect(LearningProfile.tryFromJson(null), isNull);
      expect(
        LearningProfile.tryFromJson({
          'grade': 0,
          'subjects': ['math'],
        }),
        isNull,
      );
      expect(LearningProfile.tryFromJson({'grade': 7, 'subjects': []}), isNull);
      // Fizika 6-sinfdan.
      expect(
        LearningProfile.tryFromJson({
          'grade': 5,
          'subjects': ['physics'],
        }),
        isNull,
      );
      // Noma'lum fan va takror tashlab yuboriladi.
      expect(
        LearningProfile.tryFromJson({
          'grade': 7,
          'subjects': ['math', 'math', 'astrology'],
        })?.subjects,
        [Subject.math],
      );
    });

    test('fanlar chegarasi', () {
      final tooMany = LearningProfile(
        grade: 9,
        subjects: Subject.values.take(kMaxSubjects + 1).toList(),
      );
      expect(tooMany.isValid, isFalse);
    });

    test('sinfga qarab fanlar', () {
      expect(Subject.forGrade(1), [
        Subject.math,
        Subject.english,
        Subject.native,
        Subject.russian,
      ]);
      expect(Subject.forGrade(7), Subject.values);
    });
  });

  group('TestResult JSON (API)', () {
    test('server natijasi o\'qiladi', () {
      final r = TestResult.tryFromJson({
        'id': 'r1',
        'subject': 'english',
        'topic': {'uz': 'Lug‘at', 'ru': 'Лексика', 'en': 'Vocabulary'},
        'correct': 7,
        'total': 10,
        'percent': 70,
        'isDaily': false,
        'xpEarned': 0,
        'donEarned': 0,
        'date': '2026-10-19T13:30:00.000Z',
        'durationSeconds': 95,
      })!;
      expect(r.subject, Subject.english);
      expect(r.topic.of('ru'), 'Лексика');
      expect((r.correct, r.total, r.percent), (7, 10, 70));
      expect(r.isDaily, isFalse);
      expect(r.date.isUtc, isFalse);
      expect(r.date.toUtc(), DateTime.utc(2026, 10, 19, 13, 30));
      expect(r.durationSeconds, 95);
    });

    test('mavzusiz natija ham o\'qiladi; buzilgan — null', () {
      expect(
        TestResult.tryFromJson({
          'id': 'x',
          'subject': 'math',
          'topic': null,
          'correct': 1,
          'total': 2,
          'date': '2026-10-19T10:00:00Z',
        })?.topic.of('uz'),
        '',
      );
      expect(TestResult.tryFromJson({'id': 'x'}), isNull);
      expect(
        TestResult.tryFromJson({
          'id': 'x',
          'subject': 'math',
          'correct': 11,
          'total': 10,
          'date': '2026-10-15',
        }),
        isNull,
      );
    });
  });

  group('urinish JSON (API)', () {
    Map<String, Object> question(String id) => {
      'id': id,
      'difficulty': 2,
      'topic': {'uz': 'Kasrlar', 'ru': 'Дроби', 'en': 'Fractions'},
      'prompt': {'uz': '1/2 + 1/4 = ?', 'ru': '1/2 + 1/4 = ?', 'en': '?'},
      'options': [
        for (final o in ['1/6', '3/4', '2/6', '1']) {'uz': o, 'ru': o, 'en': o},
      ],
    };

    test('urinish: savollar to\'g\'ri javobsiz, oldingi javoblar bilan', () {
      final attempt = QuizAttempt.fromJson({
        'id': 'a1',
        'subject': 'math',
        'status': 'IN_PROGRESS',
        'isDaily': true,
        'questions': [question('q1'), question('q2')],
        'answers': [
          {
            'questionId': 'q1',
            'selectedIndex': 0,
            'isCorrect': false,
            'correctIndex': 1,
            'explanation': {'uz': 'a', 'ru': 'b', 'en': 'c'},
          },
        ],
      });
      expect(attempt.questions, hasLength(2));
      expect(attempt.questions.first.options[1].of('en'), '3/4');
      expect(attempt.answers.single.correctIndex, 1);
      expect(attempt.answers.single.explanation.of('ru'), 'b');
    });

    test('tahlil', () {
      final review = AttemptReview.fromJson({
        'result': {
          'id': 'a1',
          'subject': 'math',
          'topic': null,
          'correct': 1,
          'total': 1,
          'date': '2026-10-19T10:00:00Z',
        },
        'items': [
          {
            'question': {
              ...question('q1'),
              'correctIndex': 1,
              'explanation': {'uz': 'a', 'ru': 'b', 'en': 'c'},
            },
            'selectedIndex': 1,
            'isCorrect': true,
          },
        ],
      });
      expect(review.result.correct, 1);
      expect(review.items.single.correctIndex, 1);
      expect(review.items.single.selectedIndex, 1);
    });

    test('buzilgan savol — FormatException', () {
      expect(
        () =>
            QuizQuestion.fromJson({'id': 'q', 'difficulty': 1, 'options': []}),
        throwsFormatException,
      );
    });
  });
}
