// Growth ekranining sof mantiqi: foiz va o'zgarish ko'rinishi, natija
// darajasi, test davomiyligi va sinf/fanlar varag'ining qoralamasi
// (backend qoidalari: sinf 1–11, 1–5 ta fan, fan shu sinfda o'qitiladi).

import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ko`rinish yordamchilari', () {
    test('foiz yoki "—"', () {
      expect(growthPercentLabel(null), '—');
      expect(growthPercentLabel(0), '0%');
      expect(growthPercentLabel(78), '78%');
    });

    test('o`zgarish belgisi va yo`nalishi', () {
      expect(growthTrendOf(5), GrowthTrend.up);
      expect(growthTrendOf(-3), GrowthTrend.down);
      expect(growthTrendOf(0), GrowthTrend.flat);
      expect(growthDeltaLabel(5), '+5%');
      expect(growthDeltaLabel(-3), '−3%');
      expect(growthDeltaLabel(0), '0%');
    });

    test('natija darajasi chegaralari', () {
      expect(resultLevelOf(100), ResultLevel.good);
      expect(resultLevelOf(kGoodResultPercent), ResultLevel.good);
      expect(resultLevelOf(kGoodResultPercent - 1), ResultLevel.fair);
      expect(resultLevelOf(kFairResultPercent), ResultLevel.fair);
      expect(resultLevelOf(kFairResultPercent - 1), ResultLevel.low);
      expect(resultLevelOf(0), ResultLevel.low);
    });

    test('davomiylik "daqiqa:soniya"', () {
      expect(growthDurationLabel(0), isNull);
      expect(growthDurationLabel(-5), isNull);
      expect(growthDurationLabel(7), '0:07');
      expect(growthDurationLabel(200), '3:20');
      expect(growthDurationLabel(3600), '60:00');
    });

    test('davr tugmasi kalitlari', () {
      expect(kGrowthPeriods.map(growthPeriodLabelKey), [
        'growth.period7',
        'growth.period30',
      ]);
    });
  });

  group('LearningProfileDraft', () {
    test('profil yo`q — bo`sh, saqlab bo`lmaydi', () {
      final draft = LearningProfileDraft.from(null);
      expect(draft.grade, isNull);
      expect(draft.subjects, isEmpty);
      expect(draft.available, isEmpty);
      expect(draft.canSave, isFalse);
      expect(draft.toProfile(), isNull);
    });

    test('mavjud profildan: noma`lum va o`qitilmaydigan fanlar tashlanadi', () {
      const profile = LearningProfile(
        grade: 5,
        subjects: [
          LearningSubject.math,
          LearningSubject.unknown,
          LearningSubject.chemistry, // 7-sinfdan
          LearningSubject.history,
        ],
      );
      final draft = LearningProfileDraft.from(profile);
      expect(draft.grade, 5);
      expect(draft.subjects, [LearningSubject.math, LearningSubject.history]);
      expect(draft.canSave, isTrue);
    });

    test('chegaradan tashqari sinf 1–11 ga keltiriladi', () {
      const profile = LearningProfile(
        grade: 14,
        subjects: [LearningSubject.math],
      );
      expect(LearningProfileDraft.from(profile).grade, kMaxLearningGrade);
    });

    test('sinf o`zgarsa mos kelmaydigan fanlar olib tashlanadi', () {
      final draft = const LearningProfileDraft()
          .withGrade(7)
          .toggle(LearningSubject.chemistry)
          .toggle(LearningSubject.math);
      expect(draft.subjects, [LearningSubject.chemistry, LearningSubject.math]);

      final lower = draft.withGrade(3);
      expect(lower.grade, 3);
      expect(lower.subjects, [LearningSubject.math]);
      expect(lower.available, isNot(contains(LearningSubject.chemistry)));
      // Asl qoralama o'zgarmaydi.
      expect(draft.subjects, hasLength(2));
    });

    test('noto`g`ri sinf e`tiborsiz qoldiriladi', () {
      final draft = const LearningProfileDraft().withGrade(4);
      expect(draft.withGrade(0), same(draft));
      expect(draft.withGrade(12), same(draft));
    });

    test('toggle: qo`shish, olib tashlash, sinfsiz va o`qitilmaydigan fan', () {
      const empty = LearningProfileDraft();
      expect(empty.toggle(LearningSubject.math), same(empty));

      final grade3 = empty.withGrade(3);
      expect(grade3.toggle(LearningSubject.physics), same(grade3));

      final added = grade3.toggle(LearningSubject.math);
      expect(added.isSelected(LearningSubject.math), isTrue);
      expect(added.toggle(LearningSubject.math).subjects, isEmpty);
    });

    test('5 ta to`lganda yangisi qo`shilmaydi, olib tashlash mumkin', () {
      var draft = const LearningProfileDraft().withGrade(9);
      for (final subject in LearningSubject.forGrade(9).take(5)) {
        draft = draft.toggle(subject);
      }
      expect(draft.isFull, isTrue);
      final extra = LearningSubject.forGrade(9)[5];
      expect(draft.canToggle(extra), isFalse);
      expect(draft.toggle(extra), same(draft));

      final first = draft.subjects.first;
      expect(draft.canToggle(first), isTrue);
      expect(draft.toggle(first).subjects, hasLength(4));
    });

    test('saqlanadigan profil va o`zgarish yo`qligi', () {
      final draft = const LearningProfileDraft()
          .withGrade(6)
          .toggle(LearningSubject.physics)
          .toggle(LearningSubject.math);
      final profile = draft.toProfile();
      expect(profile, isNotNull);
      expect(profile!.grade, 6);
      expect(profile.subjects, [LearningSubject.physics, LearningSubject.math]);
      expect(profile.isValid, isTrue);

      // Tartib farqi — o'zgarish emas.
      const same6 = LearningProfile(
        grade: 6,
        subjects: [LearningSubject.math, LearningSubject.physics],
      );
      expect(draft.sameAs(same6), isTrue);
      expect(draft.sameAs(null), isFalse);
      expect(draft.withGrade(7).sameAs(same6), isFalse);
    });

    test('fan tanlanmagan — saqlab bo`lmaydi', () {
      final draft = const LearningProfileDraft().withGrade(2);
      expect(draft.canSave, isFalse);
      expect(draft.toProfile(), isNull);
    });
  });
}
