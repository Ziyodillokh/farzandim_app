// Psixologik test sessiyasi (soxta soat bilan): panel `phone-runner.tsx`
// oqimi — kirish → stimul → savol, faqat oldinga, "Keyingi" javobsiz yopiq
// (MULTI — bo'sh ham javob), vaqt chegarasi va avtomatik yakun, davomiylik
// hamda server shaklidagi javoblar.

import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/psych_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'school_fixtures.dart';

final _t0 = DateTime.utc(2026, 10, 20, 9);

DateTime _at(int seconds) => _t0.add(Duration(seconds: seconds));

PsychTest _test({Object? timeLimitMin = 10, List<Object?>? items}) =>
    PsychTest.tryFromJson({
      ...psychTestJson,
      'timeLimitMin': timeLimitMin,
      'items': ?items,
    })!;

/// SINGLE (stimulus 3 s) → LIKERT → MULTI, javoblari bilan oxirigacha.
PsychSession _answerAll(PsychSession s) {
  var session = s.begin(_t0).showQuestion().choose('a');
  session = session.next(_at(10)).rate(4);
  session = session.next(_at(20)).choose('z').choose('x');
  return session.next(_at(30));
}

void main() {
  group('oqim', () {
    test('kirish: vaqt ketmaydi, "Keyingi" yo\'q', () {
      final s = PsychSession.intro(_test());

      expect(s.stage, PsychStage.intro);
      expect(s.startedAt, isNull);
      expect(s.canAdvance, isFalse);
      expect(s.progress, 0);
      expect(s.remaining(_at(600)), isNull);
      expect(s.isTimeUp(_at(6000)), isFalse);
    });

    test('stimulli savol: avval "Eslab qoling", soniyalar va keyin savol', () {
      final s = PsychSession.intro(_test()).begin(_t0);

      expect(s.stage, PsychStage.stimulus);
      expect(s.startedAt, _t0);
      expect(s.canAdvance, isFalse);
      expect(s.progress, closeTo(0.5 / 3, 1e-9));
      expect(s.stimulusSecondsLeft(_t0), 3);
      expect(s.stimulusSecondsLeft(_at(1)), 2);
      expect(
        s.stimulusSecondsLeft(_t0.add(const Duration(milliseconds: 2100))),
        1,
      );
      expect(s.isStimulusOver(_at(2)), isFalse);
      expect(s.isStimulusOver(_at(3)), isTrue);

      final question = s.showQuestion();
      expect(question.stage, PsychStage.question);
      expect(question.stimulusSecondsLeft(_at(1)), 0);
      expect(question.progress, closeTo(1 / 3, 1e-9));
      // Stimulga qaytish yo'q.
      expect(identical(question.showQuestion(), question), isTrue);
    });

    test('stimul paytida javob berib bo\'lmaydi', () {
      final s = PsychSession.intro(_test()).begin(_t0);

      expect(identical(s.choose('a'), s), isTrue);
      expect(identical(s.next(_at(1)), s), isTrue);
    });

    test('"Keyingi" javob tanlanmaguncha yopiq (SINGLE, LIKERT)', () {
      final single = PsychSession.intro(_test()).begin(_t0).showQuestion();
      expect(single.canAdvance, isFalse);
      expect(identical(single.next(_at(5)), single), isTrue);

      final likert = single.choose('a').next(_at(5));
      expect(likert.current, isA<PsychLikertItem>());
      expect(likert.canAdvance, isFalse);
      expect(likert.rate(3).canAdvance, isTrue);
    });

    test('SINGLE: oxirgi tanlov qoladi, noma\'lum kalit e\'tiborsiz', () {
      final s = PsychSession.intro(_test()).begin(_t0).showQuestion();

      final picked = s.choose('a').choose('b');
      expect((picked.currentAnswer! as PsychSingleAnswer).key, 'b');
      expect(identical(picked.choose('nope'), picked), isTrue);
    });

    test('LIKERT: faqat 1..5', () {
      final s = PsychSession.intro(_test()).begin(_t0).showQuestion();
      final likert = s.choose('a').next(_at(5));

      expect(identical(likert.rate(0), likert), isTrue);
      expect(identical(likert.rate(6), likert), isTrue);
      expect((likert.rate(5).currentAnswer! as PsychLikertAnswer).value, 5);
      // LIKERT savolida variant tanlab bo'lmaydi.
      expect(identical(likert.choose('a'), likert), isTrue);
    });

    test('MULTI: qo\'shish / olib tashlash, variantlar tartibida', () {
      final s = PsychSession.intro(_test()).begin(_t0).showQuestion();
      final multi = s.choose('a').next(_at(5)).rate(2).next(_at(9));
      expect(multi.current, isA<PsychMultiItem>());
      // Bo'sh tanlov ham javob — "Keyingi" ochiq.
      expect(multi.canAdvance, isTrue);

      final picked = multi.choose('z').choose('x').choose('y').choose('y');
      expect((picked.currentAnswer! as PsychMultiAnswer).keys, ['x', 'z']);
      expect(identical(picked.choose('nope'), picked), isTrue);
    });

    test('MULTI: hech narsa tanlamay "Keyingi" — bo\'sh javob yoziladi', () {
      final s = PsychSession.intro(_test()).begin(_t0).showQuestion();
      final done = s
          .choose('a')
          .next(_at(5))
          .rate(2)
          .next(_at(9))
          .next(_at(12));

      expect(done.stage, PsychStage.finished);
      expect(done.answers['m1'], isA<PsychMultiAnswer>());
      expect(encodePsychAnswers(done.test, done.answers), {
        's1': 'a',
        'l1': 2,
        'm1': <String>[],
      });
    });

    test('faqat oldinga: indeks faqat oshadi, yakundan keyin o\'zgarmaydi', () {
      final done = _answerAll(PsychSession.intro(_test()));

      expect(done.stage, PsychStage.finished);
      expect(done.progress, 1);
      expect(done.isRunning, isFalse);
      expect(identical(done.next(_at(40)), done), isTrue);
      expect(identical(done.choose('a'), done), isTrue);
      expect(identical(done.timeUp(_at(6000)), done), isTrue);
    });

    test('javoblar server shaklida; davomiylik — boshlashdan yakungacha', () {
      final done = _answerAll(PsychSession.intro(_test()));

      expect(done.finishedAt, _at(30));
      expect(done.durationSec, 30);
      expect(done.isTimedOut, isFalse);
      expect(encodePsychAnswers(done.test, done.answers), {
        's1': 'a',
        'l1': 4,
        'm1': ['x', 'z'],
      });
    });

    test('stimulsiz birinchi savol — darhol savol', () {
      final s = PsychSession.intro(
        _test(
          items: [
            {'id': 'l1', 'type': 'LIKERT', 'text': 'Savol'},
          ],
        ),
      ).begin(_t0);

      expect(s.stage, PsychStage.question);
      expect(s.isLast, isTrue);
      expect(s.rate(1).next(_at(4)).stage, PsychStage.finished);
    });
  });

  group('vaqt chegarasi (soxta soat)', () {
    test('teskari sanoq "Boshlash"dan', () {
      final s = PsychSession.intro(_test()).begin(_t0);

      expect(s.deadline, _at(600));
      expect(s.remaining(_t0), const Duration(minutes: 10));
      expect(s.remaining(_at(59)), const Duration(seconds: 541));
      expect(s.remaining(_at(700)), Duration.zero);
      expect(s.isTimeUp(_at(599)), isFalse);
      expect(s.isTimeUp(_at(600)), isTrue);
    });

    test('vaqt tugadi — yakun, belgilangan javoblar saqlanadi', () {
      final s = PsychSession.intro(_test()).begin(_t0).showQuestion();
      final likert = s.choose('a').next(_at(5)).rate(5);

      expect(identical(likert.timeUp(_at(599)), likert), isTrue);
      final timedOut = likert.timeUp(_at(604));

      expect(timedOut.stage, PsychStage.finished);
      expect(timedOut.isTimedOut, isTrue);
      // Davomiylik — vaqt chegarasi (ilova fonda qolgan bo'lsa ham).
      expect(timedOut.durationSec, 600);
      expect(encodePsychAnswers(timedOut.test, timedOut.answers), {
        's1': 'a',
        'l1': 5,
      });
    });

    test('stimul paytida ham vaqt tugaydi', () {
      final s = PsychSession.intro(_test(timeLimitMin: 1)).begin(_t0);

      expect(s.isTimeUp(_at(60)), isTrue);
      final timedOut = s.timeUp(_at(60));
      expect(timedOut.stage, PsychStage.finished);
      expect(timedOut.hasAnswers, isFalse);
    });

    test('chegarasiz test — vaqt tugamaydi', () {
      final s = PsychSession.intro(_test(timeLimitMin: null)).begin(_t0);

      expect(s.timeLimit, isNull);
      expect(s.remaining(_at(100000)), isNull);
      expect(s.isTimeUp(_at(100000)), isFalse);
      expect(identical(s.timeUp(_at(100000)), s), isTrue);
    });
  });
}
