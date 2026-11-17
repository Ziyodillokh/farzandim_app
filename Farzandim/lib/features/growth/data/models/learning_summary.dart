// ─────────────────────────────────────────────────────────────────────
// LearningSummary — Growth xulosasi (7 / 30 kun), ota-ona ko'rinishi
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/children/:childId/learning/summary?days=7|30
// (`learning-stats.ts` summarizeLearning + profil). Foizlar 0–100; test
// bo'lmasa `overallPercent` va boshqalar `null`.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:flutter/foundation.dart';

/// Fan bo'yicha davr natijasi.
@immutable
class SubjectStat {
  const SubjectStat({
    required this.subject,
    required this.percent,
    required this.tests,
  });

  factory SubjectStat.fromJson(Map<String, dynamic> json) => SubjectStat(
    subject: LearningSubject.fromApi(json['subject']),
    percent: json.readInt('percent').clamp(0, 100),
    tests: json.readInt('tests'),
  );

  final LearningSubject subject;
  final int percent;
  final int tests;
}

@immutable
class LearningSummary {
  const LearningSummary({
    required this.from,
    required this.to,
    required this.periodDays,
    required this.testsCount,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.subjects,
    required this.activeDays,
    required this.streakDays,
    this.profile,
    this.overallPercent,
    this.previousPercent,
    this.growthPercent,
    this.strongSubject,
    this.focusSubject,
  });

  factory LearningSummary.fromJson(Map<String, dynamic> json) =>
      LearningSummary(
        profile: LearningProfile.tryParse(json['profile']),
        from: json.readString('from'),
        to: json.readString('to'),
        periodDays: json.readInt('periodDays', fallback: kGrowthPeriods.first),
        testsCount: json.readInt('testsCount'),
        correctAnswers: json.readInt('correctAnswers'),
        totalAnswers: json.readInt('totalAnswers'),
        overallPercent: json.readIntOrNull('overallPercent'),
        previousPercent: json.readIntOrNull('previousPercent'),
        growthPercent: json.readIntOrNull('growthPercent'),
        subjects: List.unmodifiable(
          parseListSafely(
            json.readList('subjects'),
            SubjectStat.fromJson,
            tag: 'SubjectStat',
          ),
        ),
        strongSubject: _subjectOrNull(json['strongSubject']),
        focusSubject: _subjectOrNull(json['focusSubject']),
        activeDays: json.readInt('activeDays'),
        streakDays: json.readInt('streakDays'),
      );

  /// Sinf va fanlar (`updatedAt`siz); tanlanmagan → `null`.
  final LearningProfile? profile;

  /// Davr chegaralari, "YYYY-MM-DD" (Toshkent).
  final String from;
  final String to;
  final int periodDays;
  final int testsCount;
  final int correctAnswers;
  final int totalAnswers;

  /// Davr bo'yicha umumiy foiz (`null` — test yo'q).
  final int? overallPercent;

  /// Oldingi teng davr foizi.
  final int? previousPercent;

  /// `overall - previous` (ikkalasi bo'lsa); manfiy bo'lishi mumkin.
  final int? growthPercent;

  /// Fanlar (profil tartibida, keyin boshqalari).
  final List<SubjectStat> subjects;

  /// Eng yaxshi natijali fan.
  final LearningSubject? strongSubject;

  /// Ko'proq mashq tavsiya etiladigan fan (kuchli fandan farqli bo'lsa).
  final LearningSubject? focusSubject;

  /// Test yechilgan kunlar soni (davr ichida).
  final int activeDays;

  /// Ketma-ket test yechilgan kunlar (bugun yoki kechadan orqaga).
  final int streakDays;

  bool get hasTests => testsCount > 0;

  static LearningSubject? _subjectOrNull(Object? raw) =>
      raw == null ? null : LearningSubject.fromApi(raw);
}
