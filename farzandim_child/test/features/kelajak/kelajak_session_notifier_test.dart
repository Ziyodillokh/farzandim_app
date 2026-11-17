// Sessiya notifier'i: boshlash yoki davom ettirish, optimistik javob va
// xatoda qaytarish, eskirgan javoblar, ochiq matnni saqlash, yakunlash.

import 'dart:async';

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_run_state.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_kelajak_repository.dart';
import 'kelajak_fixtures.dart';

const _account = 'child-1';

ProviderContainer container(
  FakeKelajakRepository repo, {
  String? account = _account,
}) {
  final c = ProviderContainer(
    overrides: [
      kelajakRepositoryProvider.overrideWithValue(repo),
      kelajakAccountProvider.overrideWithValue(account),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Sessiyani ochib (tinglab turib) notifier'ni qaytaradi.
Future<KelajakSessionNotifier> open(ProviderContainer c, String type) async {
  c.listen(kelajakSessionProvider(type), (_, _) {});
  await c.read(kelajakSessionProvider(type).future);
  return c.read(kelajakSessionProvider(type).notifier);
}

KelajakRunState stateOf(ProviderContainer c, [String type = 'daily']) =>
    c.read(kelajakSessionProvider(type)).requireValue;

FakeKelajakRepository repoWith(String sessionFixture) =>
    FakeKelajakRepository()..onStart = (_) async => session(sessionFixture);

/// Har `PUT` javobi test boshqaradigan `Completer` orqali.
List<Completer<KelajakAnswerAck>> controlSaves(FakeKelajakRepository repo) {
  final pending = <Completer<KelajakAnswerAck>>[];
  repo.onSave = (_) {
    final completer = Completer<KelajakAnswerAck>();
    pending.add(completer);
    return completer.future;
  };
  return pending;
}

KelajakAnswerAck ack(String questionId, int value) => KelajakAnswerAck(
  questionId: questionId,
  value: value,
  sessionStatus: KelajakSessionStatus.inProgress,
  answeredCount: 1,
);

void main() {
  group('boshlash', () {
    test(
      'bugungi sessiya davom ettiriladi — birinchi javobsiz savol',
      () async {
        final repo = repoWith('session_daily_in_progress');
        final c = container(repo);
        await open(c, 'daily');
        expect(repo.starts, ['daily']);
        expect(stateOf(c).index, 3);
        expect(stateOf(c).answeredCount, 3);
      },
    );

    test('yosh kiritilmagan — xato holati (ageRequired)', () async {
      final repo = FakeKelajakRepository()
        ..onStart = (_) async =>
            throw const KelajakException(KelajakErrorCode.ageRequired);
      final c = container(repo);
      c.listen(kelajakSessionProvider('daily'), (_, _) {});
      await expectLater(
        c.read(kelajakSessionProvider('daily').future),
        throwsA(isA<KelajakException>()),
      );
      final error = c.read(kelajakSessionProvider('daily')).error;
      expect((error as KelajakException?)?.code, KelajakErrorCode.ageRequired);
    });

    test('ulanmagan — so\'rovsiz unavailable', () async {
      final repo = repoWith('session_start_daily');
      final c = container(repo, account: null);
      c.listen(kelajakSessionProvider('daily'), (_, _) {});
      await expectLater(
        c.read(kelajakSessionProvider('daily').future),
        throwsA(
          isA<KelajakException>().having(
            (e) => e.code,
            'code',
            KelajakErrorCode.unavailable,
          ),
        ),
      );
      expect(repo.starts, isEmpty);
    });

    test('bugungi holat o\'zgarsa overview qayta yuklanadi', () async {
      final repo = repoWith('session_start_daily')
        ..onOverview = () async =>
            KelajakOverview.fromJson(fixture('overview_ok_fresh'));
      final c = container(repo);
      c.listen(kelajakOverviewProvider, (_, _) {});
      await c.read(kelajakOverviewByAccountProvider(_account).future);
      expect(repo.overviewLoads, 1);

      final notifier = await open(c, 'daily');
      await c.read(kelajakOverviewByAccountProvider(_account).future);
      expect(repo.overviewLoads, 2, reason: 'NEW → STARTED');

      await notifier.select(kDailyFirstQuestion, 2);
      await c.read(kelajakOverviewByAccountProvider(_account).future);
      expect(stateOf(c).status, KelajakSessionStatus.inProgress);
      expect(repo.overviewLoads, 3, reason: 'STARTED → IN_PROGRESS');
    });
  });

  group('javob', () {
    test('optimistik: darhol ekranda, keyin server tasdig\'i', () async {
      final repo = repoWith('session_start_daily');
      final saves = controlSaves(repo);
      final c = container(repo);
      final notifier = await open(c, 'daily');

      final pending = notifier.select(kDailyFirstQuestion, 3);
      expect(stateOf(c).currentAnswer?.value, 3);
      expect(stateOf(c).isSavingQuestion(kDailyFirstQuestion), isTrue);
      expect(stateOf(c).canComplete, isFalse);
      expect(repo.saves.single.sessionId, kDailySessionId);
      expect(repo.saves.single.value, 3);
      expect(repo.saves.single.text, isNull);

      saves.single.complete(ack(kDailyFirstQuestion, 3));
      await pending;
      expect(stateOf(c).isSaving, isFalse);
      expect(stateOf(c).currentAnswer?.value, 3);
      expect(stateOf(c).status, KelajakSessionStatus.inProgress);
      expect(stateOf(c).error, isNull);
    });

    test('bir xil javob qayta yuborilmaydi', () async {
      final repo = repoWith('session_daily_in_progress');
      final c = container(repo);
      final notifier = await open(c, 'daily');
      await notifier.select(kDailyFirstQuestion, 4);
      await notifier.select(kDailyFirstQuestion, 9);
      expect(repo.saves, isEmpty);
    });

    test(
      'xato — oldingi (tasdiqlangan) javobga qaytadi, xato beriladi',
      () async {
        final repo = repoWith('session_daily_in_progress')
          ..onSave = (_) async =>
              throw const KelajakException(KelajakErrorCode.network);
        final c = container(repo);
        final notifier = await open(c, 'daily');

        await notifier.select(kDailyFirstQuestion, 1);
        expect(stateOf(c).answerFor(kDailyFirstQuestion)?.value, 4);
        expect(stateOf(c).error?.code, KelajakErrorCode.network);
        expect(stateOf(c).isSaving, isFalse);

        final fresh = stateOf(c).current.id;
        await notifier.select(fresh, 2);
        expect(stateOf(c).answerFor(fresh), isNull);
        expect(stateOf(c).canGoNext, isFalse);

        notifier.clearError();
        expect(stateOf(c).error, isNull);
      },
    );

    test('SESSION_CLOSED — sessiya yopiladi', () async {
      final repo = repoWith('session_start_daily')
        ..onSave = (_) async =>
            throw const KelajakException(KelajakErrorCode.sessionClosed);
      final c = container(repo);
      final notifier = await open(c, 'daily');
      await notifier.select(kDailyFirstQuestion, 2);
      expect(stateOf(c).isEditable, isFalse);
      expect(stateOf(c).answers, isEmpty);
      expect(stateOf(c).error?.code, KelajakErrorCode.sessionClosed);
    });
  });

  group('eskirgan javoblar', () {
    test('kechikkan eski javob yangisini bosib ketmaydi', () async {
      final repo = repoWith('session_start_daily');
      final saves = controlSaves(repo);
      final c = container(repo);
      final notifier = await open(c, 'daily');

      final first = notifier.select(kDailyFirstQuestion, 1);
      final second = notifier.select(kDailyFirstQuestion, 2);
      saves[1].complete(ack(kDailyFirstQuestion, 2));
      await second;
      expect(stateOf(c).currentAnswer?.value, 2);
      expect(stateOf(c).isSaving, isFalse);

      saves[0].complete(ack(kDailyFirstQuestion, 1));
      await first;
      expect(stateOf(c).currentAnswer?.value, 2);
    });

    test('eski so\'rov xatosi e\'tiborsiz — yangisi kutilmoqda', () async {
      final repo = repoWith('session_start_daily');
      final saves = controlSaves(repo);
      final c = container(repo);
      final notifier = await open(c, 'daily');

      final first = notifier.select(kDailyFirstQuestion, 1);
      final second = notifier.select(kDailyFirstQuestion, 2);
      saves[0].completeError(const KelajakException(KelajakErrorCode.network));
      await first;
      expect(stateOf(c).currentAnswer?.value, 2);
      expect(stateOf(c).isSavingQuestion(kDailyFirstQuestion), isTrue);
      expect(stateOf(c).error, isNull);

      saves[1].complete(ack(kDailyFirstQuestion, 2));
      await second;
      expect(stateOf(c).currentAnswer?.value, 2);
      expect(stateOf(c).isSaving, isFalse);
    });

    test('oxirgisi yiqilsa — server tasdiqlagan oldingi javob', () async {
      final repo = repoWith('session_start_daily');
      final saves = controlSaves(repo);
      final c = container(repo);
      final notifier = await open(c, 'daily');

      final first = notifier.select(kDailyFirstQuestion, 1);
      final second = notifier.select(kDailyFirstQuestion, 2);
      saves[0].complete(ack(kDailyFirstQuestion, 1));
      await first;
      expect(stateOf(c).currentAnswer?.value, 2);

      saves[1].completeError(const KelajakException(KelajakErrorCode.network));
      await second;
      expect(stateOf(c).currentAnswer?.value, 1);
      expect(stateOf(c).error?.code, KelajakErrorCode.network);
    });

    test('yangilashdan keyin eski so\'rov javobi tashlanadi', () async {
      final repo = repoWith('session_daily_in_progress');
      final saves = controlSaves(repo);
      final c = container(repo);
      final notifier = await open(c, 'daily');
      notifier.goTo(kDailySecondQuestion);

      final pending = notifier.select(kDailySecondQuestion, 1);
      await notifier.refresh();
      expect(repo.starts, ['daily', 'daily']);
      expect(stateOf(c).index, 1, reason: 'o\'sha sessiya — joriy savolda');
      expect(stateOf(c).answerFor(kDailySecondQuestion)?.value, 4);
      expect(stateOf(c).isSaving, isFalse);

      saves.single.complete(ack(kDailySecondQuestion, 1));
      await pending;
      expect(stateOf(c).answerFor(kDailySecondQuestion)?.value, 4);
    });

    test('yangilash xatosi — oldingi holat xato bilan qoladi', () async {
      final repo = repoWith('session_daily_in_progress');
      final c = container(repo);
      final notifier = await open(c, 'daily');
      repo.onStart = (_) async =>
          throw const KelajakException(KelajakErrorCode.network);
      await notifier.refresh();
      expect(stateOf(c).index, 3);
      expect(stateOf(c).error?.code, KelajakErrorCode.network);
    });
  });

  group('ochiq matn', () {
    test('o\'zgarmagan matn yuborilmaydi; bo\'sh — o\'chirish', () async {
      final repo = repoWith('session_voice_in_progress');
      final c = container(repo);
      final notifier = await open(c, 'voice');
      final saved = stateOf(c, 'voice').answerFor(kVoiceFirstQuestion)!.text!;

      await notifier.saveText(kVoiceFirstQuestion, ' $saved \n');
      expect(repo.saves, isEmpty);

      await notifier.saveText(kVoiceFirstQuestion, '  ');
      expect(repo.saves.single.text, '');
      expect(stateOf(c, 'voice').answerFor(kVoiceFirstQuestion), isNull);

      await notifier.saveText(kVoiceFirstQuestion, '  Yangi fikr ');
      expect(repo.saves.last.text, 'Yangi fikr');
      expect(
        stateOf(c, 'voice').answerFor(kVoiceFirstQuestion)?.text,
        'Yangi fikr',
      );
    });

    test('juda uzun matn — so\'rovsiz invalidAnswer', () async {
      final repo = repoWith('session_start_voice');
      final c = container(repo);
      final notifier = await open(c, 'voice');
      await notifier.saveText(kVoiceFirstQuestion, 'a' * 1001);
      expect(repo.saves, isEmpty);
      expect(stateOf(c, 'voice').error?.code, KelajakErrorCode.invalidAnswer);
      expect(stateOf(c, 'voice').answers, isEmpty);
    });

    test('"Keyingi"da saqlash — javob darhol ekranda', () async {
      final repo = repoWith('session_start_voice');
      final c = container(repo);
      final notifier = await open(c, 'voice');
      final saving = notifier.saveText(kVoiceFirstQuestion, 'Kitob o\'qish');
      notifier.next();
      expect(stateOf(c, 'voice').index, 1);
      await saving;
      notifier.back();
      expect(stateOf(c, 'voice').currentAnswer?.text, 'Kitob o\'qish');
    });
  });

  group('yakunlash', () {
    Future<(ProviderContainer, KelajakSessionNotifier, FakeKelajakRepository)>
    answered() async {
      final repo = repoWith('session_start_daily')
        ..onOverview = () async =>
            KelajakOverview.fromJson(fixture('overview_ok_today_mixed'));
      final c = container(repo);
      final notifier = await open(c, 'daily');
      for (final q in stateOf(c).questions) {
        await notifier.select(q.id, q.options.first.value);
      }
      return (c, notifier, repo);
    }

    test('natija va overview qayta yuklanadi', () async {
      final (c, notifier, repo) = await answered();
      c.listen(kelajakOverviewProvider, (_, _) {});
      await c.read(kelajakOverviewByAccountProvider(_account).future);
      final loads = repo.overviewLoads;
      repo.onComplete = (_) async => session('session_complete_daily');

      expect(await notifier.complete(), isTrue);
      expect(repo.completes, [kDailySessionId]);
      expect(stateOf(c).isCompleted, isTrue);
      expect(stateOf(c).result?.answered, 10);
      await c.read(kelajakOverviewByAccountProvider(_account).future);
      expect(repo.overviewLoads, loads + 1);
    });

    test('UNANSWERED — javobsiz savolga qaytiladi', () async {
      final (c, notifier, repo) = await answered();
      final missing = stateOf(c).questions[6].id;
      repo.onComplete = (_) async => throw KelajakException(
        KelajakErrorCode.unanswered,
        remaining: [missing],
      );
      expect(await notifier.complete(), isFalse);
      expect(stateOf(c).current.id, missing);
      expect(stateOf(c).error?.code, KelajakErrorCode.unanswered);
      expect(stateOf(c).isCompleting, isFalse);
    });

    test('shartlar bajarilmasa — so\'rovsiz', () async {
      final repo = repoWith('session_daily_in_progress');
      final c = container(repo);
      final notifier = await open(c, 'daily');
      expect(await notifier.complete(), isFalse);
      expect(repo.completes, isEmpty);
    });

    test('yakunlangan sessiya qayta ochilsa — natija bilan', () async {
      final repo = repoWith('session_complete_daily');
      final c = container(repo);
      final notifier = await open(c, 'daily');
      expect(stateOf(c).isCompleted, isTrue);
      expect(stateOf(c).result, isNotNull);
      expect(await notifier.complete(), isTrue);
      expect(repo.completes, isEmpty);
    });
  });
}
