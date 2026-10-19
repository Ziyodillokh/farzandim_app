// Kunlik test sessiyasi: tanlash → tekshirish (server) → keyingi → yakun,
// davom ettirish va tarmoq xatosi.

import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:flutter_test/flutter_test.dart';

import 'learning_fixtures.dart';

QuizAttempt attempt({List<AnswerFeedback> answers = const []}) => QuizAttempt(
  id: 'a1',
  subject: Subject.math,
  isDaily: true,
  questions: [question('q1'), question('q2'), question('q3')],
  answers: answers,
);

void main() {
  test('bo\'sh urinish bilan boshlanmaydi', () {
    expect(
      () => QuizSession.fromAttempt(
        const QuizAttempt(
          id: 'x',
          subject: Subject.math,
          isDaily: true,
          questions: [],
          answers: [],
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'tanlanmagan javobni tekshirib bo\'lmaydi, natijasiz keyingiga o\'tmaydi',
    () {
      final s = QuizSession.fromAttempt(attempt());
      expect(identical(s.startCheck(), s), isTrue);
      expect(identical(s.next(), s), isTrue);
    },
  );

  test('to\'liq oqim — server natijalari, progress va yakun', () {
    var s = QuizSession.fromAttempt(attempt()).select(1).startCheck();
    expect(s.phase, QuizPhase.checking);
    // Tekshiruv paytida javob o'zgarmaydi.
    expect(s.select(2).selectedIndex, 1);

    s = s.applyFeedback(feedback('q1', selected: 1, correct: 1));
    expect(s.phase, QuizPhase.checked);
    expect(s.currentFeedback?.isCorrect, isTrue);

    s = s
        .next()
        .select(0)
        .startCheck()
        .applyFeedback(feedback('q2', selected: 0, correct: 2));
    expect(s.outcomes, [true, false, null]);
    s = s
        .next()
        .select(3)
        .startCheck()
        .applyFeedback(feedback('q3', selected: 3, correct: 3))
        .next();

    expect(s.phase, QuizPhase.finished);
    expect(s.correctCount, 2);
    expect(s.hasProgress, isTrue);
  });

  test('boshqa savol natijasi qabul qilinmaydi', () {
    final s = QuizSession.fromAttempt(attempt()).select(1).startCheck();
    expect(identical(s.applyFeedback(feedback('q3', selected: 1)), s), isTrue);
  });

  test('tarmoq xatosi — tanlov saqlanib, qayta tekshirish mumkin', () {
    final s = QuizSession.fromAttempt(
      attempt(),
    ).select(2).startCheck().cancelCheck();
    expect(s.phase, QuizPhase.answering);
    expect(s.selectedIndex, 2);
    expect(s.startCheck().phase, QuizPhase.checking);
  });

  test('davom ettirish: javob berilganlari o\'tkaziladi', () {
    final s = QuizSession.fromAttempt(
      attempt(answers: [feedback('q1', selected: 0)]),
    );
    expect(s.index, 1);
    expect(s.phase, QuizPhase.answering);
    expect(s.outcomes, [true, null, null]);
  });

  test('davom ettirish: hammasi javob berilgan — yakunlashga tayyor', () {
    final s = QuizSession.fromAttempt(
      attempt(
        answers: [
          feedback('q1', selected: 0),
          feedback('q2', selected: 1),
          feedback('q3', selected: 0),
        ],
      ),
    );
    expect(s.index, 2);
    expect(s.phase, QuizPhase.checked);
    expect(s.next().phase, QuizPhase.finished);
  });

  test('noto\'g\'ri variant indeksi e\'tiborsiz qoldiriladi', () {
    final s = QuizSession.fromAttempt(attempt());
    expect(s.select(-1).selectedIndex, isNull);
    expect(s.select(4).selectedIndex, isNull);
  });
}
