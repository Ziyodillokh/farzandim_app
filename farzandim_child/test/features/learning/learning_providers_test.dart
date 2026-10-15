// Providerlar: profil, natija qo'shish → reja va xulosa yangilanadi,
// adaptiv savollar.

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/learning/data/learning_repository.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'learning_fixtures.dart';

class _MemoryRepository implements LearningRepository {
  LearningProfile? profile;
  final results = <TestResult>[];

  @override
  Future<LearningProfile?> loadProfile() async => profile;

  @override
  Future<void> saveProfile(LearningProfile profile) async =>
      this.profile = profile;

  @override
  Future<List<TestResult>> loadResults() async => List.of(results);

  @override
  Future<void> saveResult(TestResult result) async => results.insert(0, result);

  @override
  Future<List<QuizQuestion>> loadQuestions(Subject subject) async => [
    for (var d = 1; d <= 3; d++)
      for (var i = 0; i < 5; i++)
        question('${subject.name}-$d$i', subject: subject, difficulty: d),
  ];
}

void main() {
  final now = DateTime(2026, 10, 15, 18);

  ProviderContainer container(_MemoryRepository repo) {
    final c = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(repo),
        learningClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> load(ProviderContainer c) async {
    await c.read(savedLearningProfileProvider.future);
    await c.read(storedResultsProvider.future);
  }

  test('profil saqlansa reja shu fanlardan tuziladi', () async {
    final repo = _MemoryRepository();
    final c = container(repo);
    await load(c);

    await c
        .read(savedLearningProfileProvider.notifier)
        .save(
          const LearningProfile(
            grade: 8,
            subjects: [Subject.physics, Subject.math],
          ),
        );

    expect(repo.profile?.grade, 8);
    expect(c.read(needsLearningSetupProvider), isFalse);
    expect(c.read(dailyPlanProvider).items.map((i) => i.subject), [
      Subject.physics,
      Subject.math,
    ]);
  });

  test('natija qo\'shilsa reja va xulosa yangilanadi', () async {
    final repo = _MemoryRepository()
      ..profile = const LearningProfile(
        grade: 7,
        subjects: [Subject.math, Subject.english],
      );
    final c = container(repo);
    await load(c);
    final before = c.read(learningSummaryProvider).solvedQuestions;

    await c
        .read(storedResultsProvider.notifier)
        .add(result(Subject.math, 9, now, id: 'today'));

    final plan = c.read(dailyPlanProvider);
    expect(plan.itemFor(Subject.math)?.isDone, isTrue);
    expect(plan.nextItem?.subject, Subject.english);
    expect(c.read(learningSummaryProvider).solvedQuestions, before + 10);
    expect(repo.results.single.id, 'today');
  });

  test('profil yo\'q: preview o\'chiq bo\'lsa sozlash so\'raladi', () async {
    final c = container(_MemoryRepository());
    await load(c);
    expect(c.read(needsLearningSetupProvider), !kLearningPreviewData);
    expect(c.read(dailyPlanProvider).isEmpty, !kLearningPreviewData);
  });

  test('kunlik savollar — kerakli son, osondan qiyinga', () async {
    final repo = _MemoryRepository()
      ..profile = const LearningProfile(grade: 7, subjects: [Subject.math]);
    final c = container(repo);
    await load(c);

    final questions = await c.read(dailyQuestionsProvider(Subject.math).future);
    expect(questions, hasLength(kDailyQuestionCount));
    final difficulties = questions.map((q) => q.difficulty).toList();
    expect(difficulties, [...difficulties]..sort());
  });
}
