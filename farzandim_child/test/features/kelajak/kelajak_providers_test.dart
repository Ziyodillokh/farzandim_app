// Overview / mavjudlik, hisob almashganda eski ma'lumot ko'rinmasligi,
// rivojlanish va natijalar sahifalari.

import 'dart:async';

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_results_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_kelajak_repository.dart';
import 'kelajak_fixtures.dart';

final _account = StateProvider<String?>((ref) => 'child-1');

ProviderContainer container(FakeKelajakRepository repo) {
  final c = ProviderContainer(
    overrides: [
      kelajakRepositoryProvider.overrideWithValue(repo),
      kelajakAccountProvider.overrideWith((ref) => ref.watch(_account)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

FakeKelajakRepository overviewFrom(String name) =>
    FakeKelajakRepository()
      ..onOverview = () async => KelajakOverview.fromJson(fixture(name));

/// Overview yuklanguncha kutadi va mavjudlikni qaytaradi.
Future<bool> availability(ProviderContainer c) async {
  c
    ..listen(kelajakOverviewProvider, (_, _) {})
    ..listen(kelajakAvailableProvider, (_, _) {});
  final account = c.read(kelajakAccountProvider);
  if (account != null) {
    try {
      await c.read(kelajakOverviewByAccountProvider(account).future);
    } on KelajakException {
      // Xato holati provider'da tekshiriladi.
    }
  }
  return c.read(kelajakAvailableProvider);
}

KelajakResultsPage page(String name) =>
    KelajakResultsPage.fromJson(fixture(name));

void main() {
  group('mavjudlik', () {
    test('yosh OK yoki kiritilmagan — kirish nuqtalari ko\'rinadi', () async {
      expect(
        await availability(container(overviewFrom('overview_ok_fresh'))),
        isTrue,
      );
      final required = container(overviewFrom('overview_age_required'));
      expect(await availability(required), isTrue);
      expect(
        required.read(kelajakOverviewProvider).valueOrNull?.age.status.wire,
        'AGE_REQUIRED',
      );
    });

    test('yosh oraliqdan tashqarida — yashirin', () async {
      final c = container(overviewFrom('overview_age_out_of_range'));
      expect(await availability(c), isFalse);
    });

    test(
      'server Kelajakni bilmaydi (404 kodsiz) — yashirin, xatosiz',
      () async {
        final repo = FakeKelajakRepository()
          ..onOverview = () async =>
              throw const KelajakException(KelajakErrorCode.unavailable);
        final c = container(repo);
        expect(await availability(c), isFalse);
        final overview = c.read(kelajakOverviewProvider);
        expect(overview.hasError, isFalse);
        expect(overview.valueOrNull, isNull);
      },
    );

    test('tarmoq xatosi — yashirin, xato holatda', () async {
      final repo = FakeKelajakRepository()
        ..onOverview = () async =>
            throw const KelajakException(KelajakErrorCode.network);
      final c = container(repo);
      expect(await availability(c), isFalse);
      expect(c.read(kelajakOverviewProvider).hasError, isTrue);
    });

    test('ulanmagan — so\'rovsiz yashirin', () async {
      final repo = overviewFrom('overview_ok_fresh');
      final c = container(repo);
      c.read(_account.notifier).state = null;
      expect(await availability(c), isFalse);
      expect(repo.overviewLoads, 0);
    });

    test(
      'boshqa bolaga o\'tilganda oldingisining profili ko\'rinmaydi',
      () async {
        final repo = overviewFrom('overview_ok_with_profile');
        final c = container(repo);
        expect(await availability(c), isTrue);
        expect(c.read(kelajakOverviewProvider).valueOrNull?.profile, isNotNull);

        final next = Completer<KelajakOverview>();
        repo.onOverview = () => next.future;
        c.read(_account.notifier).state = 'child-2';
        final switching = c.read(kelajakOverviewProvider);
        expect(switching.isLoading, isTrue);
        expect(switching.valueOrNull, isNull);
        expect(c.read(kelajakAvailableProvider), isFalse);

        next.complete(KelajakOverview.fromJson(fixture('overview_ok_fresh')));
        await c.read(kelajakOverviewByAccountProvider('child-2').future);
        expect(c.read(kelajakOverviewProvider).valueOrNull?.profile, isNull);
        expect(c.read(kelajakAvailableProvider), isTrue);
      },
    );
  });

  test('rivojlanish serverdan', () async {
    final repo = FakeKelajakRepository()
      ..onProgress = () async =>
          KelajakProgress.fromJson(fixture('progress_multi_day'));
    final c = container(repo);
    c.listen(kelajakProgressProvider, (_, _) {});
    final progress = await c.read(kelajakProgressProvider.future);
    expect(progress.improved, ['school_quality', 'teacher_relation']);
    expect(progress.interestsRising, ['S']);
  });

  group('natijalar sahifalari', () {
    test(
      'birinchi sahifa, keyingisi qo\'shiladi, oxirida to\'xtaydi',
      () async {
        final repo = FakeKelajakRepository()
          ..onResults = (before, _) async => page(
            before == null ? 'results_page1_limit2' : 'results_page2_limit2',
          );
        final c = container(repo);
        c.listen(kelajakResultsProvider, (_, _) {});
        final first = await c.read(kelajakResultsProvider.future);
        expect(first.items, hasLength(2));
        expect(first.hasMore, isTrue);

        final notifier = c.read(kelajakResultsProvider.notifier);
        final loading = notifier.loadMore();
        expect(
          c.read(kelajakResultsProvider).requireValue.isLoadingMore,
          isTrue,
        );
        await notifier.loadMore();
        await loading;
        expect(repo.resultCursors, [null, '2026-10-21T04:05:52.075Z']);

        final state = c.read(kelajakResultsProvider).requireValue;
        expect(state.items, hasLength(4));
        expect(state.items.map((s) => s.id).toSet(), hasLength(4));
        expect(state.isLoadingMore, isFalse);
      },
    );

    test('keyingi sahifa xatosi ro\'yxatni o\'chirmaydi', () async {
      final repo = FakeKelajakRepository()
        ..onResults = (before, _) async => before == null
            ? page('results_page1_limit2')
            : throw const KelajakException(KelajakErrorCode.network);
      final c = container(repo);
      c.listen(kelajakResultsProvider, (_, _) {});
      await c.read(kelajakResultsProvider.future);
      await c.read(kelajakResultsProvider.notifier).loadMore();

      final state = c.read(kelajakResultsProvider).requireValue;
      expect(state.items, hasLength(2));
      expect(state.hasMore, isTrue);
      expect(state.loadMoreError?.code, KelajakErrorCode.network);
    });

    test('hammasi yuklangan — loadMore so\'rovsiz', () async {
      final repo = FakeKelajakRepository()
        ..onResults = (_, _) async => page('results_all');
      final c = container(repo);
      c.listen(kelajakResultsProvider, (_, _) {});
      final state = await c.read(kelajakResultsProvider.future);
      expect(state.items, hasLength(7));
      await c.read(kelajakResultsProvider.notifier).loadMore();
      expect(repo.resultCursors, [null]);
    });
  });
}
