// Saqlanadigan modellar JSON'i: profil, natija, savollar banki.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
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

  group('TestResult JSON', () {
    test('to\'liq qaytadi', () {
      final r = TestResult(
        id: 'r1',
        subject: Subject.english,
        topic: const LocalizedText({'uz': 'Lug‘at', 'en': 'Vocabulary'}),
        correct: 7,
        total: 10,
        date: DateTime(2026, 10, 15, 18, 30),
        answers: const [
          QuizAnswer(
            questionId: 'english-01',
            selectedIndex: 2,
            isCorrect: true,
          ),
        ],
        donEarned: 14,
        durationSeconds: 95,
      );
      final back = TestResult.tryFromJson(r.toJson())!;
      expect(back.id, 'r1');
      expect(back.subject, Subject.english);
      expect(back.topic, r.topic);
      expect(back.topic.of('ru'), 'Lug‘at');
      expect((back.correct, back.total), (7, 10));
      expect(back.date, r.date);
      expect(back.answers.single.selectedIndex, 2);
      expect(back.donEarned, 14);
      expect(back.durationSeconds, 95);
    });

    test('buzilgan yozuv — null', () {
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

  group('QuizQuestion', () {
    Map<String, Object> raw({int answer = 1}) => {
      'id': 'math-01',
      'difficulty': 2,
      'grades': [5, 9],
      'topic': {'uz': 'Kasrlar', 'ru': 'Дроби', 'en': 'Fractions'},
      'question': {'uz': '1/2 + 1/4 = ?', 'ru': '1/2 + 1/4 = ?', 'en': '?'},
      'options': [
        for (final o in ['1/6', '3/4', '2/6', '1']) {'uz': o, 'ru': o, 'en': o},
      ],
      'answer': answer,
      'explanation': {'uz': 'a', 'ru': 'b', 'en': 'c'},
    };

    test('bank yozuvi o\'qiladi', () {
      final q = QuizQuestion.fromJson(Subject.math, raw());
      expect(q.difficulty, 2);
      expect(q.fitsGrade(5), isTrue);
      expect(q.fitsGrade(10), isFalse);
      expect(q.gradeDistance(11), 2);
      expect(q.options[q.answerIndex].of('uz'), '3/4');
      expect(q.topic.of('ru'), 'Дроби');
    });

    test('javob indeksi variantlardan tashqarida — xato', () {
      expect(
        () => QuizQuestion.fromJson(Subject.math, raw(answer: 4)),
        throwsFormatException,
      );
      expect(
        () => parseQuestionBank(Subject.math, {'questions': 'x'}),
        throwsFormatException,
      );
    });
  });
}
