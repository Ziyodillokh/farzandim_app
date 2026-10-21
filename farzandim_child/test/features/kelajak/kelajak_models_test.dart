// Modellar haqiqiy server javoblarini (fixtures) o'qiydi: overview,
// sessiyalar, javoblar, natijalar, rivojlanish va tarix sahifalari.

import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kelajak_fixtures.dart';

/// Fixture nomi bo'yicha mos model (xato fixture'lari — repository testida).
Object? parse(String name) => switch (name) {
  _ when name.startsWith('overview_') => KelajakOverview.fromJson(
    fixture(name),
  ),
  _ when name.startsWith('session_') => session(name),
  _ when name.startsWith('answer_put_') => KelajakAnswerAck.fromJson(
    fixture(name),
  ),
  _ when name.startsWith('progress_') => KelajakProgress.fromJson(
    fixture(name),
  ),
  _ when name.startsWith('results_') => KelajakResultsPage.fromJson(
    fixture(name),
  ),
  _ => null,
};

void main() {
  test('barcha fixture\'lar o\'qiladi', () {
    final names = fixtureNames();
    expect(names, hasLength(39));
    for (final name in names.where((n) => !n.startsWith('error_'))) {
      expect(parse(name), isNotNull, reason: name);
    }
  });

  group('overview', () {
    test('yangi bola: 7 test, 12 kategoriya tartibda, profil yo\'q', () {
      final overview = KelajakOverview.fromJson(fixture('overview_ok_fresh'));
      expect(overview.age.status, KelajakAgeStatus.ok);
      expect(overview.age.age, 11);
      expect(overview.age.ageGroup, '10-12');
      expect(overview.tests.map((t) => t.testType), [
        KelajakTestType.daily,
        KelajakTestType.career,
        KelajakTestType.wellbeing,
        KelajakTestType.learning,
        KelajakTestType.self,
        KelajakTestType.careerLab,
        KelajakTestType.voice,
      ]);
      expect(
        overview.tests.every(
          (t) => t.today.status == KelajakTodayStatus.notStarted,
        ),
        isTrue,
      );
      expect(overview.daily?.questionCount, 10);
      expect(overview.daily?.estimatedMinutes, 3);
      expect(overview.categories, hasLength(12));
      final orders = overview.categories.map((c) => c.order).toList();
      expect(orders, [...orders]..sort());
      expect(
        overview.categoryName('career_interest')?.of('ru'),
        'Профессиональные интересы',
      );
      expect(overview.categoryName('astrology'), isNull);
      expect(overview.profile, isNull);
    });

    test('bugungi holatlar va deyarli bo\'sh profil', () {
      final overview = KelajakOverview.fromJson(
        fixture('overview_ok_today_mixed'),
      );
      expect(overview.daily?.today.status, KelajakTodayStatus.inProgress);
      expect(overview.daily?.today.sessionId, kDailySessionId);
      expect(overview.daily?.today.isUnfinished, isTrue);
      expect(overview.testOf('career_lab')?.today.isCompleted, isTrue);
      expect(
        overview.testOf('career')?.today.status,
        KelajakTodayStatus.started,
      );

      final profile = overview.profile!;
      expect(profile.answeredQuestions, 1);
      expect(profile.availableQuestions, 63);
      expect(profile.interests, isNull);
      expect(profile.insights.likedDirections.single.verdict, isNull);
      expect(
        profile.insights.triedDirections.single.verdict,
        KelajakVerdict.liked,
      );
      expect(profile.insights.support, isNull);
      expect(profile.insights.next.map((n) => n.testType), [
        'career',
        'wellbeing',
      ]);
      expect(profile.disclaimer?.of('uz'), contains('qat’iy hukm emas'));
    });

    test('to\'liq profil: qiziqishlar, kuchli tomonlar, mehribon xabar', () {
      final profile = KelajakOverview.fromJson(
        fixture('overview_ok_with_profile'),
      ).profile!;
      expect(profile.answeredQuestions, 59);
      expect(profile.completeness, closeTo(59 / 63, 1e-9));
      expect(profile.categories, isNotEmpty);
      expect(profile.interests?.top, ['A', 'I', 'S']);
      expect(profile.interests?.isReliable, isTrue);
      expect(profile.interests?.dimensions, hasLength(6));

      final insights = profile.insights;
      expect(insights.strengths.first.key, 'social_self');
      expect(insights.interests.first.code, 'A');
      expect(insights.interests.first.suggestions, isNotEmpty);
      expect(insights.growthAreas.first.tip, isNotNull);
      expect(insights.support?.level, KelajakSupportLevel.support);
      expect(insights.support?.needsAttention, isTrue);
      expect(insights.next.single.kind, KelajakNextKind.careerLab);
      expect(insights.next.single.externalId, 'PARVOZ-Q198');
    });

    test('yosh yo\'q va oraliqdan tashqarida — testlarsiz', () {
      final required = KelajakOverview.fromJson(
        fixture('overview_age_required'),
      );
      expect(required.age.status, KelajakAgeStatus.ageRequired);
      expect(required.age.age, isNull);
      expect(required.tests, isEmpty);
      expect(required.profile, isNull);

      final outOfRange = KelajakOverview.fromJson(
        fixture('overview_age_out_of_range'),
      );
      expect(outOfRange.age.status, KelajakAgeStatus.ageOutOfRange);
      expect(outOfRange.age.age, 19);
      expect(outOfRange.tests, isEmpty);
    });
  });

  group('sessiya', () {
    test('boshlangan sessiyalar: savollar soni, javob turlari', () {
      const expected = {
        'session_start_daily': 10,
        'session_start_career': 19,
        'session_start_wellbeing': 8,
        'session_start_learning': 10,
        'session_start_self': 10,
        'session_start_career_lab': 5,
        'session_start_voice': 3,
      };
      for (final MapEntry(key: name, value: count) in expected.entries) {
        final s = session(name);
        expect(s.status, KelajakSessionStatus.started, reason: name);
        expect(s.isOpen, isTrue, reason: name);
        expect(s.questions, hasLength(count), reason: name);
        expect(s.total, count, reason: name);
        expect(s.answers, isEmpty, reason: name);
        expect(s.result, isNull, reason: name);
      }
    });

    test('kunlik: interest_4 + likert_5, hammasi majburiy', () {
      final s = session('session_start_daily');
      final first = s.questions.first;
      expect(s.testType, KelajakTestType.daily);
      expect(s.day, DateTime(2026, 10, 21));
      expect(first.id, kDailyFirstQuestion);
      expect(first.externalId, 'PARVOZ-Q034');
      expect(first.answerType, KelajakAnswerType.interest4);
      expect(first.options.map((o) => o.value), [1, 2, 3, 4]);
      expect(first.options.last.label.of('en'), 'Juda yoqadi');
      expect(first.categoryName?.of('en'), 'Career interests');
      expect(first.isChoice, isTrue);
      expect(s.questions.every((q) => q.isRequired), isTrue);
    });

    test('Career Lab va ochiq fikr — ixtiyoriy', () {
      final lab = session('session_start_career_lab');
      expect(
        lab.questions.every(
          (q) => q.answerType == KelajakAnswerType.careerLab5 && !q.isRequired,
        ),
        isTrue,
      );
      final voice = session('session_start_voice').questions.first;
      expect(voice.isText, isTrue);
      expect(voice.isChoice, isFalse);
      expect(voice.isRequired, isFalse);
      expect(voice.maxLength, 1000);
      expect(voice.options, isEmpty);
    });

    test('davom etayotgan sessiya javoblari', () {
      final daily = session('session_daily_in_progress');
      expect(daily.status, KelajakSessionStatus.inProgress);
      expect(daily.answeredCount, 3);
      expect(
        daily.answers.first,
        const KelajakAnswer(questionId: kDailyFirstQuestion, value: 4),
      );
      final voice = session('session_voice_in_progress');
      expect(voice.answers.single.text, startsWith('Robot yasash'));
      expect(voice.answers.single.value, isNull);
    });

    test('yopiq wellbeing: qiymatlar yashirin, natija raqamsiz', () {
      final closed = session('session_view_wellbeing_closed');
      expect(closed.isCompleted, isTrue);
      expect(closed.answers, hasLength(8));
      expect(closed.answers.every((a) => a.isHidden), isTrue);
      expect(closed.result?.categories, isEmpty);
      expect(
        closed.result?.insights.support?.level,
        KelajakSupportLevel.support,
      );
    });

    test('yakunlangan natijalar', () {
      final daily = session('session_complete_daily').result!;
      expect(daily.answered, 10);
      expect(daily.interests, isNull);
      expect(daily.insights.triedDirections.map((d) => d.verdict), [
        KelajakVerdict.neutral,
        KelajakVerdict.liked,
        KelajakVerdict.disliked,
        KelajakVerdict.liked,
      ]);
      expect(daily.insights.likedDirections, hasLength(2));

      final career = session('session_complete_career').result!;
      expect(career.interests?.isReliable, isTrue);
      expect(career.interests?.top, containsAll(['A', 'I']));
      expect(
        career.insights.growthAreas.map((g) => g.key),
        contains('safety_rules'),
      );

      final watch = session('session_complete_wellbeing_watch').result!;
      expect(watch.insights.support?.level, KelajakSupportLevel.watch);
      expect(watch.insights.support?.message.of('uz'), isNotEmpty);

      final minimal = session('session_complete_minimal').result!;
      expect(minimal.answered, 1);
      expect(minimal.total, 5);
      expect(minimal.insights.strengths, isEmpty);
      expect(minimal.insights.support, isNull);
      expect(minimal.insights.next.map((n) => n.kind), [
        KelajakNextKind.takeTest,
        KelajakNextKind.takeTest,
      ]);
    });
  });

  test('javob: saqlash, o\'zgartirish, ochiq matn va o\'chirish', () {
    final scale = KelajakAnswerAck.fromJson(fixture('answer_put_scale'));
    expect(scale.value, 1);
    expect(scale.sessionStatus, KelajakSessionStatus.inProgress);
    expect(scale.answer?.value, 1);
    expect(
      KelajakAnswerAck.fromJson(fixture('answer_put_scale_changed')).value,
      4,
    );
    final text = KelajakAnswerAck.fromJson(fixture('answer_put_text'));
    expect(text.answer?.text, startsWith('Robot'));
    final cleared = KelajakAnswerAck.fromJson(
      fixture('answer_put_text_cleared'),
    );
    expect(cleared.isCleared, isTrue);
    expect(cleared.answer, isNull);
    expect(cleared.answeredCount, 0);
  });

  test('rivojlanish: o\'sgan kategoriyalar va qiziqishlar, tarix', () {
    expect(KelajakProgress.fromJson(fixture('progress_empty')).isEmpty, isTrue);

    final progress = KelajakProgress.fromJson(fixture('progress_multi_day'));
    expect(progress.sessionsCompleted, 7);
    expect(progress.improved, ['school_quality', 'teacher_relation']);
    expect(progress.improvedCategories.map((c) => c.delta), [25, 25]);
    expect(progress.risingInterests.single.code, 'S');
    final learning = progress.categories.firstWhere(
      (c) => c.category == 'learning',
    );
    expect(learning.previous, isNull);
    expect(learning.delta, isNull);
    expect(learning.points.single.day, DateTime(2026, 10, 17));
    expect(progress.history, hasLength(7));
    expect(progress.history.first.testType, KelajakTestType.daily);
  });

  test('natijalar sahifalari', () {
    expect(
      KelajakResultsPage.fromJson(fixture('results_empty')).hasMore,
      isFalse,
    );
    final all = KelajakResultsPage.fromJson(fixture('results_all'));
    expect(all.items, hasLength(7));
    expect(all.hasMore, isFalse);
    final page1 = KelajakResultsPage.fromJson(fixture('results_page1_limit2'));
    expect(page1.items, hasLength(2));
    expect(page1.nextBefore, '2026-10-21T04:05:52.075Z');
    expect(
      page1.items.first.completedAt,
      DateTime.utc(2026, 10, 21, 4, 5, 52, 146),
    );
  });
}
