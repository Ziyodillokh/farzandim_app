// ─────────────────────────────────────────────────────────────────────
// growth_view_models — Growth ekranining sof mantiqi (widget'siz)
// ─────────────────────────────────────────────────────────────────────
//
// Foiz ko'rinishi ("—" test bo'lmasa), o'sish belgisi (+5% / −3%), natija
// darajasi (rang tanlash uchun), test davomiyligi ("3:20") va sinf/fanlar
// varag'ining qoralamasi (backend qoidalari: sinf 1–11, 1–5 ta fan, fan
// shu sinfda o'qitilishi shart).

import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:flutter/foundation.dart';

/// Natija yaxshi hisoblanadigan chegara (foiz).
const int kGoodResultPercent = 80;

/// Natija o'rtacha hisoblanadigan chegara (foiz).
const int kFairResultPercent = 50;

/// Davr tugmasi yorlig'i kaliti (`growth.period7`, `growth.period30`).
String growthPeriodLabelKey(int days) => 'growth.period$days';

/// Foiz yoki (test bo'lmasa) "—".
String growthPercentLabel(int? percent) => percent == null ? '—' : '$percent%';

/// Oldingi davrga nisbatan o'zgarish yo'nalishi.
enum GrowthTrend { up, down, flat }

GrowthTrend growthTrendOf(int delta) => delta > 0
    ? GrowthTrend.up
    : delta < 0
    ? GrowthTrend.down
    : GrowthTrend.flat;

/// "+5%", "−3%" (haqiqiy minus belgisi), "0%".
String growthDeltaLabel(int delta) => switch (growthTrendOf(delta)) {
  GrowthTrend.up => '+$delta%',
  GrowthTrend.down => '−${delta.abs()}%',
  GrowthTrend.flat => '0%',
};

/// Natija darajasi — rang tanlash uchun.
enum ResultLevel { good, fair, low }

ResultLevel resultLevelOf(int percent) => percent >= kGoodResultPercent
    ? ResultLevel.good
    : percent >= kFairResultPercent
    ? ResultLevel.fair
    : ResultLevel.low;

/// Soniyalar → "3:20" (daqiqa:soniya); 0 yoki manfiy → `null`.
String? growthDurationLabel(int seconds) {
  if (seconds <= 0) return null;
  final minutes = seconds ~/ Duration.secondsPerMinute;
  final rest = seconds % Duration.secondsPerMinute;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

/// Sinf va fanlar varag'idagi tanlov (o'zgarmas; har amal yangi nusxa).
@immutable
class LearningProfileDraft {
  const LearningProfileDraft({this.grade, this.subjects = const []});

  /// Mavjud profildan; noma'lum va shu sinfda o'qitilmaydigan fanlar
  /// tashlanadi (backend ularni qabul qilmaydi).
  factory LearningProfileDraft.from(LearningProfile? profile) {
    if (profile == null) return const LearningProfileDraft();
    final grade = profile.grade.clamp(kMinLearningGrade, kMaxLearningGrade);
    return LearningProfileDraft(
      grade: grade,
      subjects: List.unmodifiable(
        profile.subjects
            .where((s) => s.isTaughtIn(grade))
            .toSet()
            .take(kMaxLearningSubjects),
      ),
    );
  }

  /// Tanlangan sinf (`null` — hali tanlanmagan).
  final int? grade;

  /// Tanlangan fanlar (tanlash tartibida).
  final List<LearningSubject> subjects;

  /// Tanlash mumkin bo'lgan fanlar (sinf tanlanmagan — bo'sh).
  List<LearningSubject> get available {
    final grade = this.grade;
    return grade == null ? const [] : LearningSubject.forGrade(grade);
  }

  bool get isFull => subjects.length >= kMaxLearningSubjects;

  bool isSelected(LearningSubject subject) => subjects.contains(subject);

  /// Tanlovni o'zgartirish mumkinmi: tanlanganini olib tashlash har doim,
  /// yangisini qo'shish — joy bo'lsa.
  bool canToggle(LearningSubject subject) => isSelected(subject) || !isFull;

  /// Sinf o'zgarsa — u sinfda o'qitilmaydigan fanlar olib tashlanadi.
  LearningProfileDraft withGrade(int grade) {
    if (grade < kMinLearningGrade || grade > kMaxLearningGrade) return this;
    return LearningProfileDraft(
      grade: grade,
      subjects: List.unmodifiable(subjects.where((s) => s.isTaughtIn(grade))),
    );
  }

  /// Fanni qo'shadi yoki olib tashlaydi. Sinf tanlanmagan, fan shu
  /// sinfda o'qitilmaydi yoki 5 ta to'lgan bo'lsa — o'zgarishsiz.
  LearningProfileDraft toggle(LearningSubject subject) {
    final grade = this.grade;
    if (isSelected(subject)) {
      return LearningProfileDraft(
        grade: grade,
        subjects: List.unmodifiable(subjects.where((s) => s != subject)),
      );
    }
    if (grade == null || !subject.isTaughtIn(grade) || isFull) return this;
    return LearningProfileDraft(
      grade: grade,
      subjects: List.unmodifiable([...subjects, subject]),
    );
  }

  /// Saqlanadigan profil; qoidalarga mos kelmasa — `null`.
  LearningProfile? toProfile() {
    final grade = this.grade;
    if (grade == null) return null;
    final profile = LearningProfile(grade: grade, subjects: subjects);
    return profile.isValid ? profile : null;
  }

  bool get canSave => toProfile() != null;

  /// Boshlang'ich profil bilan bir xilmi (o'zgarish yo'q — saqlash shart
  /// emas).
  bool sameAs(LearningProfile? profile) =>
      profile != null &&
      profile.grade == grade &&
      setEquals(profile.subjects.toSet(), subjects.toSet());
}
