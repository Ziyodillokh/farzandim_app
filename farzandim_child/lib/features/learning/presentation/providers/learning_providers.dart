// ─────────────────────────────────────────────────────────────────────
// Daily Learning providerlari
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ PREVIEW: Daily Learning backend'i (savollar banki, kunlik reja,
// natijalar) hali qurilmagan. Dizayn bosqichida bosh sahifa to'liq
// ko'rinishi uchun `kLearningPreviewData` yoqilgan va quyidagi providerlar
// namunaviy ma'lumot qaytaradi. Backend tayyor bo'lgach FAQAT shu fayl
// almashtiriladi (UI providerlarga bog'langan) va bayroq o'chiriladi —
// release'ga namunaviy ma'lumot bilan chiqarilmasin.

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _previewPlan = DailyPlan(
  items: [
    DailyPlanItem(subject: Subject.math, questionCount: 10),
    DailyPlanItem(subject: Subject.english, questionCount: 10),
    DailyPlanItem(subject: Subject.native, questionCount: 10),
  ],
);

const _previewSummary = LearningSummary(
  solvedQuestions: 436,
  averagePercent: 82,
  recentTestCount: 7,
  strongSubject: Subject.math,
  strongPercent: 92,
  focusSubject: Subject.english,
);

/// Bugungi testlar rejasi.
final dailyPlanProvider = Provider<DailyPlan>(
  (ref) => kLearningPreviewData ? _previewPlan : DailyPlan.empty,
);

/// So'nggi natijalar xulosasi.
final learningSummaryProvider = Provider<LearningSummary>(
  (ref) => kLearningPreviewData ? _previewSummary : LearningSummary.empty,
);
