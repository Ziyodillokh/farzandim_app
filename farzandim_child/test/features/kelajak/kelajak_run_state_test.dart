// Test yechish holati qoidalari (haqiqiy sessiyalar bilan): davom ettirish,
// tanlash / o'chirish, "Keyingi" / "Orqaga", majburiy va ixtiyoriy savollar,
// yakunlash shartlari.

import 'package:farzandim_child/features/kelajak/domain/kelajak_error.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_run_state.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kelajak_fixtures.dart';

KelajakRunState run(String name, {String? focus}) =>
    KelajakRunState.fromSession(session(name), focusQuestionId: focus);

/// Barcha majburiy savollarga birinchi variant bilan javob.
KelajakRunState answerAll(KelajakRunState state) => state.questions.fold(
  state,
  (s, q) => q.isChoice ? s.select(q.id, q.options.first.value) : s,
);

void main() {
  group('davom ettirish', () {
    test('yangi sessiya — birinchi savol', () {
      final state = run('session_start_daily');
      expect(state.index, 0);
      expect(state.position, 1);
      expect(state.total, 10);
      expect(state.isFirst, isTrue);
      expect(state.answers, isEmpty);
      expect(state.isEditable, isTrue);
    });

    test('birinchi javobsiz savoldan (3 ta javob → 4-savol)', () {
      final state = run('session_daily_in_progress');
      expect(state.index, 3);
      expect(state.answeredCount, 3);
      expect(state.answerFor(kDailyFirstQuestion)?.value, 4);
    });

    test('hammasi javob berilgan — oxirgi savol', () {
      final state = run('session_complete_daily');
      expect(state.index, state.total - 1);
      expect(state.isLast, isTrue);
    });

    test('yangilashda joriy savolda qoladi', () {
      final state = run(
        'session_daily_in_progress',
        focus: kDailySecondQuestion,
      );
      expect(state.index, 1);
      final unknown = run('session_daily_in_progress', focus: 'yo\'q');
      expect(unknown.index, 3);
    });

    test('savolsiz sessiya — ArgumentError', () {
      final json = fixture('session_start_daily')..['questions'] = [];
      expect(
        () => KelajakRunState.fromSession(KelajakSession.fromJson(json)),
        throwsArgumentError,
      );
    });
  });

  group('javob tanlash', () {
    test('faqat shu savol variantlaridan', () {
      final state = run('session_start_daily');
      final selected = state.select(kDailyFirstQuestion, 3);
      expect(selected.currentAnswer?.value, 3);
      expect(state.answers, isEmpty, reason: 'eski holat o\'zgarmaydi');

      expect(state.select(kDailyFirstQuestion, 9), same(state));
      expect(state.select('yo\'q', 1), same(state));
      expect(selected.select(kDailyFirstQuestion, 3), same(selected));
      expect(selected.select(kDailyFirstQuestion, 1).currentAnswer?.value, 1);
    });

    test('ochiq savolga variant tanlanmaydi, shkalaga matn yozilmaydi', () {
      final voice = run('session_start_voice');
      expect(voice.select(kVoiceFirstQuestion, 1), same(voice));
      final daily = run('session_start_daily');
      expect(daily.writeText(kDailyFirstQuestion, 'salom'), same(daily));
    });

    test('ochiq matn: bo\'shliqsiz, bo\'sh — o\'chirish, uzuni — rad', () {
      final voice = run('session_start_voice');
      final written = voice.writeText(kVoiceFirstQuestion, '  Robot  ');
      expect(written.currentAnswer?.text, 'Robot');
      expect(written.writeText(kVoiceFirstQuestion, 'Robot '), same(written));
      expect(written.writeText(kVoiceFirstQuestion, '   ').answers, isEmpty);
      expect(voice.writeText(kVoiceFirstQuestion, ''), same(voice));
      expect(voice.writeText(kVoiceFirstQuestion, 'a' * 1001), same(voice));
      expect(
        voice.writeText(kVoiceFirstQuestion, 'a' * 1000).currentAnswer?.text,
        hasLength(1000),
      );
    });

    test('javobni o\'chirish', () {
      final state = run('session_daily_in_progress');
      final cleared = state.clear(kDailyFirstQuestion);
      expect(cleared.answerFor(kDailyFirstQuestion), isNull);
      expect(cleared.answeredCount, 2);
      expect(cleared.clear(kDailyFirstQuestion), same(cleared));
    });

    test('yopiq sessiyada javob o\'zgarmaydi', () {
      final done = run('session_complete_daily');
      expect(done.isEditable, isFalse);
      final q = done.current;
      expect(done.select(q.id, q.options.last.value), same(done));
      expect(done.clear(q.id), same(done));
    });
  });

  group('Keyingi / Orqaga', () {
    test('majburiy savol javobsiz — "Keyingi" yopiq', () {
      final state = run('session_start_daily');
      expect(state.current.isRequired, isTrue);
      expect(state.canGoNext, isFalse);
      expect(state.next(), same(state));

      final answered = state.select(kDailyFirstQuestion, 2);
      expect(answered.canGoNext, isTrue);
      expect(answered.next().index, 1);
    });

    test('ixtiyoriy savolni o\'tkazib yuborish mumkin', () {
      final lab = run('session_start_career_lab');
      expect(lab.current.isRequired, isFalse);
      expect(lab.canGoNext, isTrue);
      expect(lab.next().index, 1);

      final voice = run('session_start_voice');
      expect(voice.canGoNext, isTrue);
      expect(voice.next().next().index, 2);
    });

    test('"Orqaga" javoblarni saqlaydi; chegaralarda joyida qoladi', () {
      final state = run('session_start_daily');
      expect(state.canGoBack, isFalse);
      expect(state.back(), same(state));

      final moved = state.select(kDailyFirstQuestion, 4).next();
      final back = moved.back();
      expect(back.index, 0);
      expect(back.currentAnswer?.value, 4);
      expect(back.next().index, 1);

      final last = answerAll(state).goTo(state.questions.last.id);
      expect(last.isLast, isTrue);
      expect(last.next(), same(last));
    });

    test('goTo — faqat sessiya savollariga', () {
      final state = run('session_start_daily');
      expect(state.goTo(state.questions[5].id).index, 5);
      expect(state.goTo('yo\'q'), same(state));
      expect(state.goTo(kDailyFirstQuestion), same(state));
    });
  });

  group('yakunlash shartlari', () {
    test('majburiylarning hammasi kerak (tartibda ro\'yxat)', () {
      final state = run('session_daily_in_progress');
      expect(state.missingRequired, hasLength(7));
      expect(state.missingRequired.first, state.questions[3].id);
      expect(state.canComplete, isFalse);
      final full = answerAll(state);
      expect(full.missingRequired, isEmpty);
      expect(full.canComplete, isTrue);
    });

    test('faqat ixtiyoriy savolli test — kamida bitta javob', () {
      final lab = run('session_start_career_lab');
      expect(lab.missingRequired, isEmpty);
      expect(lab.canComplete, isFalse);
      final q = lab.current;
      expect(lab.select(q.id, 5).canComplete, isTrue);

      final voice = run('session_start_voice');
      expect(voice.canComplete, isFalse);
      expect(voice.writeText(kVoiceFirstQuestion, 'fikr').canComplete, isTrue);
    });

    test('saqlanayotgan javob yoki yakunlanayotganda — yopiq', () {
      final full = answerAll(run('session_start_daily'));
      final saving = full.startSaving(kDailyFirstQuestion);
      expect(saving.isSaving, isTrue);
      expect(saving.isSavingQuestion(kDailyFirstQuestion), isTrue);
      expect(saving.canComplete, isFalse);
      final saved = saving.finishSaving(kDailyFirstQuestion);
      expect(saved.canComplete, isTrue);
      expect(saved.finishSaving(kDailyFirstQuestion), same(saved));

      final completing = saved.startCompleting();
      expect(completing.isCompleting, isTrue);
      expect(completing.canComplete, isFalse);
      expect(completing.isEditable, isFalse);
      expect(completing.startCompleting(), same(completing));
      expect(
        run('session_start_daily').startCompleting().isCompleting,
        isFalse,
      );
    });

    test('yakunlandi — natija, savollar o\'zgarmaydi', () {
      final completing = answerAll(
        run('session_start_daily'),
      ).startCompleting();
      final done = completing.completed(session('session_complete_daily'));
      expect(done.isCompleted, isTrue);
      expect(done.isCompleting, isFalse);
      expect(done.isEditable, isFalse);
      expect(done.result?.answered, 10);
      expect(done.questions, same(completing.questions));
      expect(completing.result, isNull);
    });

    test('UNANSWERED — server ro\'yxati bo\'yicha tuzatiladi', () {
      final full = answerAll(
        run('session_daily_in_progress'),
      ).startCompleting();
      final remaining = [full.questions[5].id, full.questions[7].id];
      final failed = full.completeFailed(
        KelajakException(KelajakErrorCode.unanswered, remaining: remaining),
      );
      expect(failed.isCompleting, isFalse);
      expect(failed.error?.code, KelajakErrorCode.unanswered);
      expect(failed.missingRequired, remaining);
      expect(failed.index, 5);
      expect(failed.isEditable, isTrue);
    });

    test('SESSION_CLOSED — sessiya yopiladi; boshqa xato — faqat xabar', () {
      final full = answerAll(run('session_start_daily')).startCompleting();
      final closed = full.completeFailed(
        const KelajakException(KelajakErrorCode.sessionClosed),
      );
      expect(closed.status, KelajakSessionStatus.abandoned);
      expect(closed.isEditable, isFalse);

      final offline = full.completeFailed(
        const KelajakException(KelajakErrorCode.network),
      );
      expect(offline.isOpen, isTrue);
      expect(offline.canComplete, isTrue);
      expect(offline.error?.code, KelajakErrorCode.network);
      expect(offline.clearError().error, isNull);
    });
  });

  group('server bilan kelishuv', () {
    test('restore: tasdiqlangan javobga qaytish (yopiqda ham)', () {
      final state = run('session_daily_in_progress');
      final changed = state.select(kDailyFirstQuestion, 1);
      expect(
        changed
            .restore(
              kDailyFirstQuestion,
              const KelajakAnswer(questionId: kDailyFirstQuestion, value: 4),
            )
            .answerFor(kDailyFirstQuestion)
            ?.value,
        4,
      );
      final closed = changed.close();
      expect(closed.isOpen, isFalse);
      expect(closed.restore(kDailyFirstQuestion, null).answeredCount, 2);
      expect(closed.close(), same(closed));
      expect(state.restore('yo\'q', null), same(state));
      expect(
        state.restore(
          kDailyFirstQuestion,
          const KelajakAnswer(questionId: kDailyFirstQuestion, value: 4),
        ),
        same(state),
      );
    });

    test('server holati: STARTED → IN_PROGRESS, noma\'lumi e\'tiborsiz', () {
      final state = run('session_start_daily');
      expect(state.status, KelajakSessionStatus.started);
      final progressed = state.withStatus(KelajakSessionStatus.inProgress);
      expect(progressed.status, KelajakSessionStatus.inProgress);
      expect(
        progressed.withStatus(KelajakSessionStatus.unknown),
        same(progressed),
      );
    });

    test('xato holati', () {
      final state = run(
        'session_start_daily',
      ).withError(const KelajakException(KelajakErrorCode.network));
      expect(state.error?.code, KelajakErrorCode.network);
      final cleared = state.clearError();
      expect(cleared.error, isNull);
      expect(cleared.clearError(), same(cleared));
    });
  });
}
