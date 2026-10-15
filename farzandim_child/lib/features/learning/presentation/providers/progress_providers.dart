// ─────────────────────────────────────────────────────────────────────
// Rivojlanish providerlari
// ─────────────────────────────────────────────────────────────────────
//
// Hammasi `learningResultsProvider`dan hisoblanadi (`learning_stats.dart`)
// — bosh sahifa xulosasi bilan doim izchil.

import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haftalik rivojlanish (`null` — hali natija yo'q).
final weeklyProgressProvider = Provider<WeeklyProgress?>(
  (ref) => weeklyProgress(
    ref.watch(learningResultsProvider),
    ref.watch(learningClockProvider)(),
  ),
);

/// Fanlar bo'yicha o'zlashtirish (profil fanlari birinchi).
final subjectScoresProvider = Provider<List<SubjectScore>>(
  (ref) => subjectScores(
    ref.watch(learningResultsProvider),
    order: ref.watch(learningProfileProvider)?.subjects ?? const [],
  ),
);

/// Test natijalari — yangisi birinchi.
final recentResultsProvider = Provider<List<TestResult>>(
  (ref) => ref.watch(learningResultsProvider),
);

/// Bugungi tavsiya — eng past natijali fan (`null` — tavsiya yo'q).
final progressRecommendationProvider = Provider<ProgressRecommendation?>(
  (ref) => recommendation(ref.watch(subjectScoresProvider)),
);
