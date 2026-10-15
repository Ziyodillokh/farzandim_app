// ─────────────────────────────────────────────────────────────────────
// Rivojlanish providerlari
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ PREVIEW (`kLearningPreviewData`): Daily Learning backend'i qurilguncha
// namunaviy ma'lumot. Bosh sahifadagi xulosa bilan izchil: umumiy 82%,
// kuchli fan — Matematika 92%, tavsiya — Ingliz tili. Backend tayyor
// bo'lgach FAQAT shu fayl almashtiriladi.

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haftalik rivojlanish (`null` — hali natija yo'q).
final weeklyProgressProvider = Provider<WeeklyProgress?>(
  (ref) => kLearningPreviewData
      ? const WeeklyProgress(
          growthPercent: 12,
          overallPercent: 82,
          testsThisWeek: 7,
          correctAnswers: 12,
          successStreak: 3,
        )
      : null,
);

/// Tanlangan fanlar bo'yicha o'zlashtirish.
final subjectScoresProvider = Provider<List<SubjectScore>>(
  (ref) => kLearningPreviewData
      ? const [
          SubjectScore(subject: Subject.math, percent: 92),
          SubjectScore(subject: Subject.english, percent: 65),
          SubjectScore(subject: Subject.native, percent: 78),
        ]
      : const [],
);

/// So'nggi test natijalari — yangisi birinchi.
final recentResultsProvider = Provider<List<TestResult>>((ref) {
  if (!kLearningPreviewData) return const [];
  final now = DateTime.now();
  DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d);
  return [
    TestResult(
      id: 'r1',
      subject: Subject.math,
      topic: 'Arifmetika',
      correct: 9,
      total: 10,
      date: daysAgo(0),
    ),
    TestResult(
      id: 'r2',
      subject: Subject.english,
      topic: 'Grammar',
      correct: 7,
      total: 10,
      date: daysAgo(1),
    ),
    TestResult(
      id: 'r3',
      subject: Subject.native,
      topic: 'Matn tahlili',
      correct: 8,
      total: 10,
      date: daysAgo(2),
    ),
    TestResult(
      id: 'r4',
      subject: Subject.math,
      topic: 'Kasrlar',
      correct: 10,
      total: 10,
      date: daysAgo(3),
    ),
    TestResult(
      id: 'r5',
      subject: Subject.english,
      topic: 'Vocabulary',
      correct: 5,
      total: 10,
      date: daysAgo(4),
    ),
  ];
});

/// Bugungi tavsiya — eng past natijali fan (`null` — tavsiya yo'q).
final progressRecommendationProvider = Provider<ProgressRecommendation?>((ref) {
  final scores = ref.watch(subjectScoresProvider);
  if (scores.isEmpty) return null;
  final weakest = scores.reduce((a, b) => a.percent <= b.percent ? a : b);
  return ProgressRecommendation(subject: weakest.subject, testCount: 10);
});
