// Growth provayderlari (soxta repository bilan): Growth mavjud emasligi
// kartani yashiradi (`null`), natijalar `nextBefore` bilan sahifalanadi,
// profil saqlash `Result` qaytarib xulosani yangilaydi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/features/growth/data/learning_repository.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LearningResult _result(String id) => LearningResult.fromJson({
  'id': id,
  'subject': 'math',
  'correct': 8,
  'total': 10,
  'percent': 80,
});

class _FakeLearningRepository extends LearningRepository {
  _FakeLearningRepository() : super(dio: Dio());

  Exception? summaryError;
  int summaryFetches = 0;

  /// Kursor (`null` — birinchi sahifa) → sahifa yoki xato.
  final Map<String?, Object> pages = {};
  final List<String?> resultCursors = [];

  /// Natija so'rovini qo'lda tugatish uchun (poyga holatlari).
  Completer<void>? resultsGate;
  Exception? saveError;

  @override
  Future<LearningSummary> fetchSummary(String childId, {int days = 7}) async {
    summaryFetches++;
    final error = summaryError;
    if (error != null) throw error;
    return LearningSummary.fromJson({'testsCount': days, 'periodDays': days});
  }

  @override
  Future<LearningResultsPage> fetchResults(
    String childId, {
    int limit = kLearningResultsPageSize,
    String? before,
    LearningSubject? subject,
  }) async {
    resultCursors.add(before);
    await resultsGate?.future;
    return switch (pages[before]) {
      final LearningResultsPage page => page,
      final Exception error => throw error,
      _ => throw const SchoolFailure(SchoolFailureKind.unknown),
    };
  }

  @override
  Future<LearningProfile> saveProfile(
    String childId,
    LearningProfile profile,
  ) async {
    final error = saveError;
    if (error != null) throw error;
    return profile;
  }
}

void main() {
  late _FakeLearningRepository repo;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [learningRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Notifier konstruktoridagi birinchi yuklash tugashini kutadi.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() => repo = _FakeLearningRepository());

  group('growthSummaryProvider', () {
    test('davr bo`yicha xulosa', () async {
      final container = makeContainer();
      final summary = await container.read(
        growthSummaryProvider((childId: 'kid-1', days: 30)).future,
      );
      expect(summary?.periodDays, 30);
    });

    test('Growth mavjud emas → null (karta yashiriladi)', () async {
      repo.summaryError = const SchoolFailure(SchoolFailureKind.unavailable);
      final container = makeContainer();
      final summary = await container.read(
        growthSummaryProvider((childId: 'kid-1', days: 7)).future,
      );
      expect(summary, isNull);
    });

    test('tarmoq xatosi — AsyncError (qayta urinish)', () async {
      repo.summaryError = const SchoolFailure(SchoolFailureKind.network);
      final container = makeContainer();
      await expectLater(
        container.read(
          growthSummaryProvider((childId: 'kid-1', days: 7)).future,
        ),
        throwsA(const SchoolFailure(SchoolFailureKind.network)),
      );
    });
  });

  group('GrowthResultsNotifier', () {
    test('birinchi sahifa, keyingisi va oxiri', () async {
      repo.pages[null] = LearningResultsPage(
        items: [_result('r-1'), _result('r-2')],
        nextBefore: 'c-1',
      );
      repo.pages['c-1'] = LearningResultsPage(items: [_result('r-3')]);
      final container = makeContainer();
      final sub = container.listen(growthResultsProvider('kid-1'), (_, _) {});
      addTearDown(sub.close);
      expect(sub.read().initialLoading, isTrue);

      await settle();
      expect(sub.read().initialLoading, isFalse);
      expect(sub.read().items.map((r) => r.id), ['r-1', 'r-2']);
      expect(sub.read().hasMore, isTrue);

      await container.read(growthResultsProvider('kid-1').notifier).loadMore();
      expect(sub.read().items.map((r) => r.id), ['r-1', 'r-2', 'r-3']);
      expect(sub.read().hasMore, isFalse);

      await container.read(growthResultsProvider('kid-1').notifier).loadMore();
      expect(repo.resultCursors, [null, 'c-1'], reason: 'oxirida so`rov yo`q');
    });

    test(
      'sahifa xatosi: kursor saqlanadi, qayta urinish davom etadi',
      () async {
        repo.pages[null] = LearningResultsPage(
          items: [_result('r-1')],
          nextBefore: 'c-1',
        );
        repo.pages['c-1'] = const SchoolFailure(SchoolFailureKind.network);
        final container = makeContainer();
        final sub = container.listen(growthResultsProvider('kid-1'), (_, _) {});
        addTearDown(sub.close);
        await settle();
        final notifier = container.read(
          growthResultsProvider('kid-1').notifier,
        );

        await notifier.loadMore();
        expect(sub.read().failure?.kind, SchoolFailureKind.network);
        expect(sub.read().nextBefore, 'c-1');
        expect(sub.read().items.map((r) => r.id), ['r-1']);

        repo.pages['c-1'] = LearningResultsPage(items: [_result('r-2')]);
        await notifier.loadMore();
        expect(sub.read().failure, isNull);
        expect(sub.read().items.map((r) => r.id), ['r-1', 'r-2']);
      },
    );

    test('birinchi sahifa xatosi — failure, ro`yxat bo`sh', () async {
      repo.pages[null] = const SchoolFailure(SchoolFailureKind.unavailable);
      final container = makeContainer();
      final sub = container.listen(growthResultsProvider('kid-1'), (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(sub.read().initialLoading, isFalse);
      expect(sub.read().failure?.isUnavailable, isTrue);
      expect(sub.read().items, isEmpty);
    });

    test('refresh paytida kechikkan loadMore natijasi qo`shilmaydi', () async {
      repo.pages[null] = LearningResultsPage(
        items: [_result('r-1')],
        nextBefore: 'c-1',
      );
      repo.pages['c-1'] = LearningResultsPage(items: [_result('eski')]);
      final container = makeContainer();
      final sub = container.listen(growthResultsProvider('kid-1'), (_, _) {});
      addTearDown(sub.close);
      await settle();
      final notifier = container.read(growthResultsProvider('kid-1').notifier);

      final gate = repo.resultsGate = Completer<void>();
      final more = notifier.loadMore();
      repo.pages[null] = LearningResultsPage(items: [_result('yangi')]);
      final refresh = notifier.refresh();
      gate.complete();
      await Future.wait([more, refresh]);

      expect(sub.read().items.map((r) => r.id), ['yangi']);
      expect(sub.read().hasMore, isFalse);
    });
  });

  group('GrowthActionsNotifier', () {
    const profile = LearningProfile(grade: 6, subjects: [LearningSubject.math]);

    test('saqlash → Result.success va xulosa qayta yuklanadi', () async {
      final container = makeContainer();
      const key = (childId: 'kid-1', days: 7);
      final sub = container.listen(growthSummaryProvider(key), (_, _) {});
      addTearDown(sub.close);
      await container.read(growthSummaryProvider(key).future);
      expect(repo.summaryFetches, 1);

      final result = await container
          .read(growthActionsProvider.notifier)
          .saveProfile('kid-1', profile);

      expect(result.isSuccess, isTrue);
      expect(result.data, profile);
      await container.read(growthSummaryProvider(key).future);
      expect(repo.summaryFetches, 2);
    });

    test('xato → Result.failure (tarjima kaliti)', () async {
      repo.saveError = const SchoolFailure(SchoolFailureKind.validation);
      final container = makeContainer();
      final result = await container
          .read(growthActionsProvider.notifier)
          .saveProfile('kid-1', profile);
      expect(result.isSuccess, isFalse);
      expect(result.error, 'school.errors.validation');
      expect(container.read(growthActionsProvider).hasError, isTrue);
    });
  });
}
