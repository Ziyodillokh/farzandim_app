// Providerlar: server profili / natijalari → reja, xulosa; sozlash kartasi
// faqat "profil yo'q" bo'lganda (tarmoq xatosida emas).

import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_learning_repository.dart';
import 'learning_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 19, 18);

  ProviderContainer container(FakeLearningRepository repo) {
    final c = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(repo),
        learningClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Profil va natijalar yuklanishini kutish (xato bo'lsa ham).
  Future<void> load(ProviderContainer c) async {
    try {
      await c.read(savedLearningProfileProvider.future);
    } on LearningException {
      // Tarmoq xatosi testi — holat provider'da tekshiriladi.
    }
    await c.read(storedResultsProvider.future);
  }

  test('profil va natijalardan reja va xulosa', () async {
    final repo = FakeLearningRepository(
      profile: const LearningProfile(
        grade: 7,
        subjects: [Subject.math, Subject.english],
      ),
      results: [
        result(Subject.math, 9, now.subtract(const Duration(hours: 2))),
      ],
    );
    final c = container(repo);
    await load(c);

    final plan = c.read(dailyPlanProvider);
    expect(plan.items.map((i) => i.subject), [Subject.math, Subject.english]);
    expect(plan.itemFor(Subject.math)?.isDone, isTrue);
    expect(plan.nextItem?.subject, Subject.english);
    expect(c.read(learningSummaryProvider).solvedQuestions, 10);
    expect(c.read(needsLearningSetupProvider), isFalse);
  });

  test('profil saqlansa reja yangilanadi', () async {
    final repo = FakeLearningRepository();
    final c = container(repo);
    await load(c);
    expect(c.read(needsLearningSetupProvider), isTrue);
    expect(c.read(dailyPlanProvider).isEmpty, isTrue);

    await c
        .read(savedLearningProfileProvider.notifier)
        .save(const LearningProfile(grade: 6, subjects: [Subject.physics]));
    expect(repo.profile?.grade, 6);
    expect(c.read(needsLearningSetupProvider), isFalse);
    expect(c.read(dailyPlanProvider).items.single.subject, Subject.physics);
  });

  test('tarmoq xatosida sozlash kartasi chiqmaydi', () async {
    final repo = FakeLearningRepository()
      ..failNext = const LearningException(LearningErrorCode.network);
    final c = container(repo);
    await load(c);
    expect(c.read(savedLearningProfileProvider).hasError, isTrue);
    expect(c.read(needsLearningSetupProvider), isFalse);
  });

  test('yakunlangan natija ro\'yxat boshiga qo\'shiladi (takrorsiz)', () async {
    final repo = FakeLearningRepository(
      profile: const LearningProfile(grade: 7, subjects: [Subject.math]),
    );
    final c = container(repo);
    await load(c);
    final notifier = c.read(storedResultsProvider.notifier);
    final r = result(Subject.math, 8, now, id: 'r1');
    notifier
      ..add(r)
      ..add(r);
    expect(c.read(learningResultsProvider).map((x) => x.id), ['r1']);
    expect(c.read(dailyPlanProvider).isComplete, isTrue);
  });

  test('test urinishi repository orqali (davom ettirish bilan)', () async {
    final repo = FakeLearningRepository(
      profile: const LearningProfile(grade: 7, subjects: [Subject.math]),
    );
    final c = container(repo);
    final first = await c.read(quizAttemptProvider(Subject.math).future);
    await repo.submitAnswer(
      attemptId: first.id,
      questionId: first.questions.first.id,
      selectedIndex: 0,
    );
    c.invalidate(quizAttemptProvider(Subject.math));
    final resumed = await c.read(quizAttemptProvider(Subject.math).future);
    expect(resumed.id, first.id);
    expect(resumed.answers, hasLength(1));
  });
}
