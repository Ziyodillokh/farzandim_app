// ─────────────────────────────────────────────────────────────────────
// Daily Learning providerlari
// ─────────────────────────────────────────────────────────────────────
//
// Manba — server (`ApiLearningRepository`, `/api/learning`). Profil va
// natijalar serverdan; reja, xulosa va Rivojlanish ko'rsatkichlari shu
// natijalardan ilovada hisoblanadi (`learning_stats.dart`). Test urinishi
// (savollar, javob tekshiruvi, DON) — butunlay serverda.

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/learning/data/api_learning_repository.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => ApiLearningRepository(ref.watch(dioClientProvider)),
);

/// Hozirgi vaqt (testlarda almashtiriladi).
final learningClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Serverdagi o'quv profili.
final savedLearningProfileProvider =
    AsyncNotifierProvider<LearningProfileNotifier, LearningProfile?>(
      LearningProfileNotifier.new,
    );

class LearningProfileNotifier extends AsyncNotifier<LearningProfile?> {
  @override
  Future<LearningProfile?> build() =>
      ref.watch(learningRepositoryProvider).loadProfile();

  Future<void> save(LearningProfile profile) async {
    final saved = await ref
        .read(learningRepositoryProvider)
        .saveProfile(profile);
    state = AsyncData(saved);
  }
}

/// Amaldagi profil (yuklanmagan / xato bo'lsa `null`).
final learningProfileProvider = Provider<LearningProfile?>(
  (ref) => ref.watch(savedLearningProfileProvider).valueOrNull,
);

/// Profil yoki natijalar hali yuklanmoqda.
final learningLoadingProvider = Provider<bool>((ref) {
  final profile = ref.watch(savedLearningProfileProvider);
  final results = ref.watch(storedResultsProvider);
  return (profile.isLoading && !profile.hasValue) ||
      (results.isLoading && !results.hasValue);
});

/// Profil tanlanishi kerak — server "profil yo'q" degan (tarmoq xatosida
/// emas: oflaynda sozlash kartasi chiqib qolmasin).
final needsLearningSetupProvider = Provider<bool>((ref) {
  final profile = ref.watch(savedLearningProfileProvider);
  return profile.hasValue && !profile.hasError && profile.value == null;
});

/// Serverdagi natijalar — yangisi birinchi.
final storedResultsProvider =
    AsyncNotifierProvider<LearningResultsNotifier, List<TestResult>>(
      LearningResultsNotifier.new,
    );

class LearningResultsNotifier extends AsyncNotifier<List<TestResult>> {
  @override
  Future<List<TestResult>> build() =>
      ref.watch(learningRepositoryProvider).loadResults();

  /// Yakunlangan test natijasi (server allaqachon saqlagan) — ro'yxatga.
  void add(TestResult result) {
    final current = state.valueOrNull ?? const <TestResult>[];
    state = AsyncData(
      List.unmodifiable([result, ...current.where((r) => r.id != result.id)]),
    );
  }
}

/// Barcha natijalar — yangisi birinchi.
final learningResultsProvider = Provider<List<TestResult>>(
  (ref) => ref.watch(storedResultsProvider).valueOrNull ?? const <TestResult>[],
);

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

/// Fan bo'yicha test urinishi (yangi yoki davom ettirilgan) — ekran
/// yopilganda tashlanadi.
final quizAttemptProvider = FutureProvider.autoDispose
    .family<QuizAttempt, Subject>(
      (ref, subject) =>
          ref.read(learningRepositoryProvider).startAttempt(subject),
    );

/// Yakunlangan test tahlili.
final attemptReviewProvider = FutureProvider.autoDispose
    .family<AttemptReview, String>(
      (ref, resultId) =>
          ref.read(learningRepositoryProvider).loadReview(resultId),
    );

/// Pastga tortib yangilash: profil va natijalarni serverdan qayta yuklash
/// (tarmoq xatosi indikatorni to'xtatmaydi — holat provider'larda qoladi).
Future<void> refreshLearning(WidgetRef ref) async {
  ref
    ..invalidate(savedLearningProfileProvider)
    ..invalidate(storedResultsProvider);
  try {
    await Future.wait([
      ref.read(savedLearningProfileProvider.future),
      ref.read(storedResultsProvider.future),
    ]);
  } on LearningException {
    // Oflayn — kartalar avvalgi / bo'sh holatda qoladi.
  }
}
