// Kunlik test sessiyasi: tanlash → tekshirish → keyingi → yakun, DON.

import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:flutter_test/flutter_test.dart';

import 'learning_fixtures.dart';

void main() {
  final start = DateTime(2026, 10, 15, 18);
  QuizSession session() => QuizSession.start(
    subject: Subject.math,
    questions: [
      question('q1', answer: 1, topic: 'Kasrlar'),
      question('q2', answer: 2, topic: 'Tenglamalar'),
      question('q3', answer: 0, topic: 'Kasrlar'),
    ],
    startedAt: start,
  );

  test('bo\'sh savollar bilan boshlanmaydi', () {
    expect(
      () => QuizSession.start(
        subject: Subject.math,
        questions: const [],
        startedAt: start,
      ),
      throwsArgumentError,
    );
  });

  test('tanlanmagan javobni tekshirib bo\'lmaydi', () {
    final s = session();
    expect(identical(s.check(), s), isTrue);
    expect(identical(s.next(), s), isTrue);
  });

  test('to\'liq oqim — javoblar, to\'g\'rilari, yakun va natija', () {
    var s = session().select(1).check();
    expect(s.phase, QuizPhase.checked);
    expect(s.currentAnswer?.isCorrect, isTrue);
    // Tekshirilgandan keyin javob o'zgarmaydi.
    expect(s.select(3).selectedIndex, 1);

    s = s.next().select(0).check();
    expect(s.currentAnswer?.isCorrect, isFalse);
    s = s.next().select(0).check().next();

    expect(s.phase, QuizPhase.finished);
    expect(s.correctCount, 2);
    expect(s.answers.map((a) => a.questionId), ['q1', 'q2', 'q3']);

    final r = s.toResult(
      id: 'r1',
      finishedAt: start.add(const Duration(minutes: 3)),
    );
    expect(r.correct, 2);
    expect(r.total, 3);
    expect(r.durationSeconds, 180);
    expect(r.donEarned, donFor(2, 3));
    expect(r.topic.of('uz'), 'Kasrlar');
    expect(r.canReview, isTrue);
  });

  test('noto\'g\'ri variant indeksi e\'tiborsiz qoldiriladi', () {
    final s = session();
    expect(s.select(-1).selectedIndex, isNull);
    expect(s.select(4).selectedIndex, isNull);
  });

  test('DON — har to\'g\'ri javob + mukammal natija bonusi', () {
    expect(donFor(0, 10), 0);
    expect(donFor(7, 10), 7 * kDonPerCorrect);
    expect(donFor(10, 10), 10 * kDonPerCorrect + kPerfectBonusDon);
    expect(donFor(3, 0), 0);
  });
}
