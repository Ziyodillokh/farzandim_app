// KelajakDashboardCard va Growth'dagi havola o'zi yashirinadi: yuklanmoqda,
// xato, bo'lim yo'q (404 `code`siz) yoki 7–18 dan tashqari (javobsiz).
// Ko'rinsa: top yo'nalishlar / "hali javob yo'q" / yosh so'rovi; bosilsa
// Kelajak sahifasi. Ilovaga qaytilganda (resume) karta xulosani yangilaydi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_dashboard_card.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_growth_link.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'kelajak_fixtures.dart';

class _FakeKelajakRepository extends KelajakRepository {
  _FakeKelajakRepository() : super(dio: Dio());

  Map<String, dynamic>? json = kelajakFixtureJson(kRichSupportFixture);
  SchoolFailure? failure;
  Completer<void>? hold;
  int fetches = 0;

  @override
  Future<KelajakSummary> fetchSummary(String childId) async {
    fetches++;
    await hold?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return KelajakSummary.fromJson(json!);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeKelajakRepository repo, {
  Widget card = const KelajakDashboardCard(childId: 'kid-1'),
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: ListView(children: [card])),
      ),
      GoRoute(
        path: '/kelajak/:childId',
        builder: (_, state) =>
            Scaffold(body: Text('kelajak:${state.pathParameters['childId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [kelajakRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _cardTitle => find.text('kelajak.card.title');

void main() {
  late _FakeKelajakRepository repo;

  setUp(() => repo = _FakeKelajakRepository());

  group('yashirin holatlar', () {
    testWidgets('yuklanmoqda', (tester) async {
      repo.hold = Completer<void>();
      await _pump(tester, repo);
      expect(_cardTitle, findsNothing);
      repo.hold!.complete();
      await tester.pumpAndSettle();
      expect(_cardTitle, findsOneWidget);
    });

    testWidgets('bo`lim yo`q (404 code`siz)', (tester) async {
      repo.failure = const SchoolFailure(SchoolFailureKind.unavailable);
      await _pump(tester, repo);
      expect(_cardTitle, findsNothing);
    });

    testWidgets('ruxsat yo`q yoki tarmoq xatosi', (tester) async {
      repo.failure = const SchoolFailure(SchoolFailureKind.forbidden);
      await _pump(tester, repo);
      expect(_cardTitle, findsNothing);
    });

    testWidgets('7–18 dan tashqari va javobsiz', (tester) async {
      repo.json = {
        ...kelajakFixtureJson(kEmptyFixture),
        'age': {'status': 'AGE_OUT_OF_RANGE', 'age': 5, 'ageGroup': null},
      };
      await _pump(tester, repo);
      expect(_cardTitle, findsNothing);
    });
  });

  group('ko`rinadigan holatlar', () {
    testWidgets('boy profil → top yo`nalishlar; bosilsa Kelajak', (
      tester,
    ) async {
      await _pump(tester, repo);
      expect(_cardTitle, findsOneWidget);
      expect(find.text('kelajak.card.interests'), findsOneWidget);

      await tester.tap(_cardTitle);
      await tester.pumpAndSettle();
      expect(find.text('kelajak:kid-1'), findsOneWidget);
    });

    testWidgets('javob yo`q → "hali javob yo`q"', (tester) async {
      repo.json = kelajakFixtureJson(kEmptyFixture);
      await _pump(tester, repo);
      expect(find.text('kelajak.card.empty'), findsOneWidget);
    });

    testWidgets('yosh kiritilmagan → yosh so`raladi', (tester) async {
      repo.json = kelajakFixtureJson(kAgeRequiredFixture);
      await _pump(tester, repo);
      expect(find.text('kelajak.card.ageRequired'), findsOneWidget);
    });

    testWidgets('testlar bor, yo`nalish hali yo`q → shakllanmoqda', (
      tester,
    ) async {
      repo.json = kelajakFixtureJson(kWatchFixture);
      await _pump(tester, repo);
      expect(find.text('kelajak.card.forming'), findsOneWidget);
    });
  });

  testWidgets('ilovaga qaytilganda xulosa qayta so`raladi', (tester) async {
    await _pump(tester, repo);
    expect(repo.fetches, 1);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(repo.fetches, 2);
    expect(_cardTitle, findsOneWidget);
  });

  group('Growth sahifasidagi havola', () {
    testWidgets('Kelajak bor → havola; bosilsa Kelajak sahifasi', (
      tester,
    ) async {
      await _pump(
        tester,
        repo,
        card: const KelajakGrowthLink(childId: 'kid-1'),
      );
      expect(find.text('kelajak.link.title'), findsOneWidget);

      await tester.tap(find.text('kelajak.link.title'));
      await tester.pumpAndSettle();
      expect(find.text('kelajak:kid-1'), findsOneWidget);
    });

    testWidgets('bo`lim yo`q → havola yo`q', (tester) async {
      repo.failure = const SchoolFailure(SchoolFailureKind.unavailable);
      await _pump(
        tester,
        repo,
        card: const KelajakGrowthLink(childId: 'kid-1'),
      );
      expect(find.text('kelajak.link.title'), findsNothing);
    });
  });
}
