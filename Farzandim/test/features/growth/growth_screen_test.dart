// GrowthScreen: natijalar ro'yxati sahifa ochiq turganda tirik — xulosa
// yuklanayotganda aylantirish har kadrda yangi `GET /learning/results`
// yubormaydi, 7 ↔ 30 almashtirilganda yuklangan natijalar qayta
// so'ralmaydi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/growth/data/learning_repository.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/features/growth/presentation/screens/growth_screen.dart';
import 'package:farzandim/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLearningRepository extends LearningRepository {
  _FakeLearningRepository() : super(dio: Dio());

  /// Berilsa, xulosa shu tugaguncha kutadi (yuklanmoqda holati).
  Completer<void>? holdSummary;
  final List<String?> resultCursors = [];

  @override
  Future<LearningSummary> fetchSummary(String childId, {int days = 7}) async {
    await holdSummary?.future;
    return LearningSummary.fromJson({'testsCount': 0, 'periodDays': days});
  }

  @override
  Future<LearningResultsPage> fetchResults(
    String childId, {
    int limit = kLearningResultsPageSize,
    String? before,
    LearningSubject? subject,
  }) async {
    resultCursors.add(before);
    return LearningResultsPage(
      items: [
        LearningResult.fromJson({
          'id': 'r-${before ?? 0}',
          'subject': 'math',
          'correct': 8,
          'total': 10,
          'percent': 80,
        }),
      ],
      nextBefore: before == null ? 'c-1' : null,
    );
  }
}

/// Kelajak havolasi (sahifada) — bo'lim yo'q, tarmoqqa chiqmaydi.
class _NoKelajakRepository extends KelajakRepository {
  _NoKelajakRepository() : super(dio: Dio());

  @override
  Future<KelajakSummary> fetchSummary(String childId) async =>
      throw const SchoolFailure(SchoolFailureKind.unavailable);
}

Future<void> _pump(WidgetTester tester, _FakeLearningRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learningRepositoryProvider.overrideWithValue(repo),
        kelajakRepositoryProvider.overrideWithValue(_NoKelajakRepository()),
        childByIdProvider.overrideWith((ref, id) => null),
      ],
      child: const MaterialApp(home: GrowthScreen(childId: 'kid-1')),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('xulosa yuklanayotganda aylantirish natijani qayta so`ramaydi', (
    tester,
  ) async {
    final repo = _FakeLearningRepository()..holdSummary = Completer<void>();
    await _pump(tester, repo);

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump(const Duration(milliseconds: 100));

    // Bitta ro'yxat (birinchi sahifa) — har kadrda yangisi emas, keyingi
    // sahifa ham so'ralmaydi (bo'lim hali ko'rinmaydi).
    expect(repo.resultCursors, [null]);

    repo.holdSummary!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('7 ↔ 30 almashtirilganda natijalar qayta so`ralmaydi', (
    tester,
  ) async {
    final repo = _FakeLearningRepository();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(repo.resultCursors, [null]);

    final longer = kGrowthPeriods.last;
    await tester.tap(find.text(growthPeriodLabelKey(longer)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(growthPeriodLabelKey(kGrowthPeriods.first)));
    await tester.pumpAndSettle();

    expect(repo.resultCursors, [null]);
  });
}
