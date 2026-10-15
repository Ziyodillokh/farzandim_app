// ─────────────────────────────────────────────────────────────────────
// Daily Learning providerlari
// ─────────────────────────────────────────────────────────────────────
//
// Manba — `LearningRepository` (hozircha lokal: profil va natijalar
// qurilmada, savollar ilova ichidagi bankda). Backend ulanganda faqat
// `learningRepositoryProvider` almashtiriladi; reja, xulosa va
// Rivojlanish ko'rsatkichlari natijalardan hisoblanadi
// (`learning_stats.dart`).
//
// ⚠️ PREVIEW (`kLearningPreviewData`): profil tanlanmagan bo'lsa namunaviy
// profil, o'tgan kunlar uchun namunaviy natijalar qo'shiladi (bugun — real).
// Release'ga bayroq o'chirilgan holda chiqiladi.

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/data/local_learning_repository.dart';
import 'package:farzandim_child/features/learning/data/preview_history.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/question_picker.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preview rejimidagi namunaviy profil.
const kPreviewLearningProfile = LearningProfile(
  grade: 7,
  subjects: [Subject.math, Subject.english, Subject.native],
);

/// Yaqinda berilgan savollar shu kunlar ichida takrorlanmaydi.
const _recentQuestionDays = 3;

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LocalLearningRepository(),
);

/// Hozirgi vaqt (testlarda almashtiriladi).
final learningClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Saqlangan o'quv profili.
final savedLearningProfileProvider =
    AsyncNotifierProvider<LearningProfileNotifier, LearningProfile?>(
      LearningProfileNotifier.new,
    );

class LearningProfileNotifier extends AsyncNotifier<LearningProfile?> {
  @override
  Future<LearningProfile?> build() =>
      ref.watch(learningRepositoryProvider).loadProfile();

  Future<void> save(LearningProfile profile) async {
    await ref.read(learningRepositoryProvider).saveProfile(profile);
    state = AsyncData(profile);
  }
}

/// Amaldagi profil (yuklanayotganda `null`). Preview rejimida tanlanmagan
/// bo'lsa namunaviy profil.
final learningProfileProvider = Provider<LearningProfile?>((ref) {
  final saved = ref.watch(savedLearningProfileProvider);
  if (saved.isLoading && !saved.hasValue) return null;
  return saved.valueOrNull ??
      (kLearningPreviewData ? kPreviewLearningProfile : null);
});

/// Profil yoki natijalar hali yuklanmoqda.
final learningLoadingProvider = Provider<bool>((ref) {
  final profile = ref.watch(savedLearningProfileProvider);
  final results = ref.watch(storedResultsProvider);
  return (profile.isLoading && !profile.hasValue) ||
      (results.isLoading && !results.hasValue);
});

/// Profil tanlanishi kerak (yuklangan, lekin yo'q).
final needsLearningSetupProvider = Provider<bool>(
  (ref) =>
      !ref.watch(learningLoadingProvider) &&
      ref.watch(learningProfileProvider) == null,
);

/// Qurilmada saqlangan natijalar.
final storedResultsProvider =
    AsyncNotifierProvider<LearningResultsNotifier, List<TestResult>>(
      LearningResultsNotifier.new,
    );

class LearningResultsNotifier extends AsyncNotifier<List<TestResult>> {
  @override
  Future<List<TestResult>> build() =>
      ref.watch(learningRepositoryProvider).loadResults();

  Future<void> add(TestResult result) async {
    await ref.read(learningRepositoryProvider).saveResult(result);
    final current = state.valueOrNull ?? const <TestResult>[];
    state = AsyncData(
      List.unmodifiable([result, ...current.where((r) => r.id != result.id)]),
    );
  }
}

/// Barcha natijalar — yangisi birinchi (preview: + namunaviy tarix).
final learningResultsProvider = Provider<List<TestResult>>((ref) {
  final stored =
      ref.watch(storedResultsProvider).valueOrNull ?? const <TestResult>[];
  final profile = ref.watch(learningProfileProvider);
  if (!kLearningPreviewData || profile == null) return stored;
  final now = ref.watch(learningClockProvider)();
  // Bola o'zi yechgan kun/fan uchun namunaviy natija qo'shilmaydi.
  bool solved(TestResult p) =>
      stored.any((s) => s.subject == p.subject && isSameDay(s.date, p.date));
  return List.unmodifiable(
    [...stored, ...previewHistory(profile, now).where((p) => !solved(p))]
      ..sort((a, b) => b.date.compareTo(a.date)),
  );
});

/// Bugungi testlar rejasi.
final dailyPlanProvider = Provider<DailyPlan>(
  (ref) => buildDailyPlan(
    ref.watch(learningProfileProvider),
    ref.watch(learningResultsProvider),
    ref.watch(learningClockProvider)(),
  ),
);

/// So'nggi natijalar xulosasi.
final learningSummaryProvider = Provider<LearningSummary>(
  (ref) => summarize(
    ref.watch(learningResultsProvider),
    order: ref.watch(learningProfileProvider)?.subjects ?? const [],
  ),
);

/// Ketma-ket test yechilgan kunlar.
final learningStreakProvider = Provider<int>(
  (ref) => learningStreak(
    ref.watch(learningResultsProvider),
    ref.watch(learningClockProvider)(),
  ),
);

/// Fan bo'yicha bugungi test savollari — adaptiv tanlov. Sessiya davomida
/// natijalar o'zgarsa ham savollar qayta tanlanmaydi (`read`).
final dailyQuestionsProvider = FutureProvider.autoDispose
    .family<List<QuizQuestion>, Subject>((ref, subject) async {
      final pool = await ref
          .read(learningRepositoryProvider)
          .loadQuestions(subject);
      final results = ref.read(learningResultsProvider);
      final now = ref.read(learningClockProvider)();
      final since = DateTime(
        now.year,
        now.month,
        now.day - _recentQuestionDays,
      );
      return pickQuestions(
        pool: pool,
        grade: (ref.read(learningProfileProvider) ?? kPreviewLearningProfile)
            .grade,
        count: kDailyQuestionCount,
        recentPercent: recentPercentFor(subject, results),
        recentlySeen: {
          for (final r in results)
            if (r.date.isAfter(since))
              for (final a in r.answers) a.questionId,
        },
        seed: dailySeed(now, subject.index),
      );
    });

/// Savollar banki (ko'rib chiqish sahifasi uchun — id bo'yicha).
final questionBankProvider = FutureProvider.autoDispose
    .family<Map<String, QuizQuestion>, Subject>((ref, subject) async {
      final pool = await ref
          .read(learningRepositoryProvider)
          .loadQuestions(subject);
      return {for (final q in pool) q.id: q};
    });
