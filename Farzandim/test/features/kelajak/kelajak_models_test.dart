// Kelajak modellari backend'ning haqiqiy javoblarini (fixtures) to'g'ri
// o'qiydi: yosh holati, kategoriyalar, qiziqishlar, Career Lab (reytingsiz),
// qo'llab-quvvatlash signali (raqamsiz), progress. Buzuq element butun
// xulosani yiqitmaydi; ro'yxatlar o'zgarmas.

import 'package:farzandim/features/kelajak/data/models/kelajak_insights.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_support.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kelajak_fixtures.dart';

void main() {
  group('boy profil (rich_support)', () {
    final summary = kelajakFixture(kRichSupportFixture);

    test('yosh, sessiyalar va kategoriyalar', () {
      expect(summary.age.status, KelajakAgeStatus.ok);
      expect(summary.age.age, 11);
      expect(summary.age.ageGroup, '10-12');
      expect(summary.sessionsCompleted, 7);
      expect(summary.hasAnswers, isTrue);
      expect(
        summary.lastCompletedAt,
        DateTime.parse('2026-10-21T04:05:52.146Z').toLocal(),
      );
      expect(summary.categories.map((c) => c.category), [
        'learning',
        'school_quality',
        'teacher_relation',
        'social_self',
        'career_planning',
        'personal_traits',
      ]);
      expect(
        summary.categories.first.name?.of('uz'),
        'Fanlar va o‘rganish tajribasi',
      );
      expect(summary.categories[1].score, 13);
      expect(summary.categories[1].answered, 4);
    });

    test('qiziqishlar: RIASEC nomlari va top yo`nalishlar', () {
      final interests = summary.interests!;
      expect(interests.dimensions, hasLength(6));
      expect(interests.top, ['A', 'I', 'S']);
      expect(interests.reliable, isTrue);
      expect(interests.nameOf('A')?.of('uz'), 'Ijodiy');
      expect(interests.nameOf('R')?.of('ru'), 'Практический');
      expect(interests.nameOf('X'), isNull);
      expect(interests.nameOf(null), isNull);
    });

    test('insight`lar: kuchli tomon, yo`nalish, Career Lab, maslahat', () {
      final insights = summary.insights;
      expect(insights.strengths.map((s) => s.key), [
        'social_self',
        'career_planning',
        'personal_traits',
      ]);
      final creative = insights.interests.first;
      expect(creative.code, 'A');
      expect(creative.title.of('en'), 'Creative direction');
      expect(creative.body?.of('uz'), contains('qiziqish yuqori'));
      expect(creative.suggestions.map((s) => s.of('uz')), [
        'dizayn',
        'san’at va musiqa',
        'jurnalistika va yozuvchilik',
        'media va video',
      ]);
      expect(insights.likedDirections, hasLength(2));
      expect(insights.likedDirections.first.code, 'R');
      expect(insights.triedDirections.map((t) => t.verdict), [
        KelajakVerdict.neutral,
        KelajakVerdict.liked,
        KelajakVerdict.disliked,
        KelajakVerdict.liked,
      ]);
      expect(insights.growthAreas.map((a) => a.key).last, 'safety_rules');
      expect(insights.growthAreas.first.tip?.of('uz'), isNotEmpty);
      expect(insights.next.single.kind, KelajakNextKind.careerLab);
      expect(insights.next.single.testType, 'career_lab');
    });

    test('signal: daraja, sohalar, sana — raqamsiz', () {
      final support = summary.support!;
      expect(support.level, KelajakSupportLevel.support);
      expect(support.areas.map((a) => a.key), ['safety', 'wellbeing']);
      expect(support.day, '2026-10-18');
      expect(support.guidance?.of('uz'), contains('Bu tashxis emas'));
    });

    test('progress: oldingi natija va o`zgarish', () {
      final categories = summary.progress.categories;
      expect(categories, hasLength(6));
      final school = categories[1];
      expect(school.category, 'school_quality');
      expect((school.latest, school.previous, school.delta), (25, 0, 25));
      expect(school.points.map((p) => p.day), ['2026-10-17', '2026-10-21']);
      expect(categories.first.previous, isNull);
      expect(categories.first.delta, isNull);
      final social = summary.progress.interests.firstWhere(
        (i) => i.code == 'S',
      );
      expect(social.delta, 100);
      expect(summary.progress.isEmpty, isFalse);
      expect(summary.disclaimer?.of('uz'), contains('qat’iy kasb hukmi emas'));
    });
  });

  test('bo`sh profil: javob yo`q, signal yo`q, test tavsiyalari', () {
    final summary = kelajakFixture(kEmptyFixture);
    expect(summary.age.status, KelajakAgeStatus.ok);
    expect(summary.sessionsCompleted, 0);
    expect(summary.hasAnswers, isFalse);
    expect(summary.lastCompletedAt, isNull);
    expect(summary.categories, isEmpty);
    expect(summary.interests, isNull);
    expect(summary.support, isNull);
    expect(summary.progress.isEmpty, isTrue);
    expect(summary.insights.next.map((n) => (n.kind, n.testType)), [
      (KelajakNextKind.takeTest, 'career'),
      (KelajakNextKind.takeTest, 'wellbeing'),
    ]);
  });

  test('yosh kiritilmagan: AGE_REQUIRED', () {
    final summary = kelajakFixture(kAgeRequiredFixture);
    expect(summary.age.status, KelajakAgeStatus.ageRequired);
    expect(summary.age.age, isNull);
    expect(summary.age.ageGroup, isNull);
  });

  test('watch: bitta soha, ehtiyotkor matn', () {
    final support = kelajakFixture(kWatchFixture).support!;
    expect(support.level, KelajakSupportLevel.watch);
    expect(support.areas.single.key, 'wellbeing');
    expect(support.guidance?.of('ru'), contains('Это не диагноз'));
  });

  group('himoyali parse', () {
    test('bo`sh yoki buzuq javob yiqilmaydi', () {
      final summary = KelajakSummary.fromJson(const {
        'age': 'x',
        'sessionsCompleted': -3,
        'lastCompletedAt': 'kecha',
        'categories': 'yo`q',
        'interests': 5,
        'insights': null,
        'support': {'level': 'none'},
      });
      expect(summary.age.status, KelajakAgeStatus.unknown);
      expect(summary.sessionsCompleted, 0);
      expect(summary.lastCompletedAt, isNull);
      expect(summary.categories, isEmpty);
      expect(summary.interests, isNull);
      expect(summary.insights.strengths, isEmpty);
      expect(summary.support, isNull);
      expect(summary.disclaimer, isNull);
    });

    test('nomsiz/kodsiz element tashlanadi, qolgani ko`rinadi', () {
      final insights = KelajakInsights.fromJson(const {
        'strengths': [
          {'key': 'social_self'},
          {
            'key': 'learning',
            'title': {'uz': 'O‘rganish'},
          },
          'buzuq',
        ],
        'triedDirections': [
          {
            'activity': {'uz': 'Tajriba'},
            'code': null,
            'verdict': 'yangi',
          },
        ],
      });
      expect(insights.strengths.single.key, 'learning');
      expect(insights.triedDirections.single.verdict, KelajakVerdict.unknown);
      expect(insights.triedDirections.single.direction.code, isNull);
    });

    test('noma`lum signal darajasi → signal yo`q', () {
      expect(KelajakSupport.tryParse({'level': 'critical'}), isNull);
      expect(KelajakSupport.tryParse(null), isNull);
    });

    test('ro`yxatlar o`zgarmas', () {
      final summary = kelajakFixture(kRichSupportFixture);
      expect(
        () => summary.insights.strengths.add(summary.insights.strengths.first),
        throwsUnsupportedError,
      );
      expect(summary.categories.clear, throwsUnsupportedError);
      expect(
        () => summary.insights.interests.first.suggestions.removeLast(),
        throwsUnsupportedError,
      );
    });

    test('til yo`q bo`lsa o`zbekcha', () {
      const text = LocalizedText({'uz': 'Ijodiy'});
      expect(text.of('ru'), 'Ijodiy');
      expect(text.of('en'), 'Ijodiy');
    });
  });
}
