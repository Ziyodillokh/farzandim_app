// "Kelajagim" hub'i (yosh holati, testlar va holati, mavzular) va "Kelajak
// profilim" sahifasi (mavzu o'zgarishi, o'sgan qiziqishlar, sahifalangan
// tarix).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/routing/kelajak_routes.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_hub_screen.dart';
import 'package:farzandim_child/features/kelajak/presentation/screens/kelajak_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_kelajak_repository.dart';
import 'kelajak_test_app.dart';

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

Future<void> _pumpHub(
  WidgetTester tester,
  FakeKelajakRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) => pumpKelajakApp(
  tester,
  repository: repo,
  size: size,
  textScale: textScale,
  initialLocation: KelajakRoutes.hub,
  routes: [
    GoRoute(
      path: KelajakRoutes.hub,
      builder: (_, _) => const KelajakHubScreen(),
    ),
    kelajakMarker(KelajakRoutes.session),
    kelajakMarker(KelajakRoutes.progress),
    kelajakMarker(KelajakRoutes.ageEdit),
  ],
);

Future<void> _pumpProgress(
  WidgetTester tester,
  FakeKelajakRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) => pumpKelajakApp(
  tester,
  repository: repo,
  size: size,
  textScale: textScale,
  initialLocation: KelajakRoutes.progress,
  routes: [
    GoRoute(
      path: KelajakRoutes.progress,
      builder: (_, _) => const KelajakProgressScreen(),
    ),
    kelajakMarker(KelajakRoutes.hub),
  ],
);

/// Ro'yxatni [finder] ko'ringuncha aylantiradi va yangi joylashuvni chizadi.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUpAll(setUpKelajakWidgetTests);

  group('hub', () {
    testWidgets('yosh, testlar holati bilan va mavzular', (tester) async {
      await _pumpHub(tester, kelajakRepo());

      expect(tester.takeException(), isNull);
      expect(
        find.text(_t('kelajak.age.line', {'age': '11', 'group': '10–12'})),
        findsOneWidget,
      );
      expect(find.text('Kunlik savollar'), findsOneWidget);
      expect(find.text('10 ta savol · 3 daqiqa'), findsWidgets);
      expect(find.text(_t('kelajak.status.completed')), findsWidgets);
      expect(find.text(_t('kelajak.status.new')), findsWidgets);

      await _scrollTo(tester, find.text(_t('kelajak.hub.topics')));
      await _scrollTo(tester, find.text('Bola ovozi — ochiq fikr va murojaat'));
      expect(find.text('Kasbiy qiziqishlar'), findsWidgets);
    });

    testWidgets('test kartasi shu turdagi testni ochadi', (tester) async {
      await _pumpHub(tester, kelajakRepo());

      await tester.tap(find.text('Kayfiyat va farovonlik'));
      await tester.pumpAndSettle();

      expect(
        find.text('page:${KelajakRoutes.session}:wellbeing'),
        findsOneWidget,
      );
    });

    testWidgets('"Kelajak profilim" havolasi', (tester) async {
      await _pumpHub(tester, kelajakRepo());

      final link = find.text(_t('kelajak.progress.title'));
      await _scrollTo(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.text('page:${KelajakRoutes.progress}'), findsOneWidget);
    });

    testWidgets('yosh kiritilmagan — profil sahifasiga yo\'naltirish', (
      tester,
    ) async {
      await _pumpHub(tester, kelajakRepo(overview: 'overview_age_required'));

      expect(find.text(_t('kelajak.age.requiredTitle')), findsOneWidget);
      expect(find.text(_t('kelajak.hub.tests')), findsNothing);
      await tester.tap(find.text(_t('kelajak.age.requiredAction')));
      await tester.pumpAndSettle();

      expect(find.text('page:${KelajakRoutes.ageEdit}'), findsOneWidget);
    });

    testWidgets('yosh oraliqdan tashqarida — tushuntirish', (tester) async {
      await _pumpHub(
        tester,
        kelajakRepo(overview: 'overview_age_out_of_range'),
      );

      expect(find.text(_t('kelajak.age.outOfRangeTitle')), findsOneWidget);
      expect(find.text(_t('kelajak.hub.tests')), findsNothing);
    });

    testWidgets('oflayn — xato va "Qayta urinish"', (tester) async {
      var fail = true;
      final repo = kelajakRepo();
      final load = repo.onOverview;
      repo.onOverview = () async {
        if (fail) throw const KelajakException(KelajakErrorCode.network);
        return load();
      };
      await _pumpHub(tester, repo);

      expect(find.text(_t('kelajak.errors.network')), findsOneWidget);
      fail = false;
      await tester.tap(find.text(_t('common.retry')));
      await settleKelajak(tester);

      expect(find.text('Kunlik savollar'), findsOneWidget);
    });

    testWidgets('turi berilmagan test manzili (deep-link) hub\'ga qaytadi', (
      tester,
    ) async {
      final repo = kelajakRepo();
      await pumpKelajakApp(
        tester,
        repository: repo,
        initialLocation: KelajakRoutes.session,
        routes: kelajakRoutes,
      );
      await tester.pumpAndSettle();

      expect(find.text(_t('kelajak.hub.tests')), findsOneWidget);
      expect(repo.starts, isEmpty);
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      await _pumpHub(
        tester,
        kelajakRepo(overview: 'overview_ok_today_mixed'),
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_t('kelajak.status.inProgress')), findsWidgets);
    });
  });

  group('"Kelajak profilim" sahifasi', () {
    testWidgets('mavzular o\'zgarishi va o\'sgan qiziqishlar', (tester) async {
      await _pumpProgress(tester, kelajakRepo());

      expect(tester.takeException(), isNull);
      expect(
        find.text(_t('kelajak.progress.subtitle', {'count': '7'})),
        findsOneWidget,
      );
      expect(find.text('Maktab sifati va darslar'), findsOneWidget);
      expect(find.text('+25'), findsNWidgets(2));
      // `learning` — bitta o'lchov.
      expect(find.text(_t('kelajak.progress.first')), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      await _scrollTo(tester, find.text(_t('kelajak.progress.rising')));
      expect(find.text('Ijtimoiy'), findsOneWidget);
    });

    testWidgets('tarix sahifalab yuklanadi', (tester) async {
      final repo = kelajakRepo();
      await _pumpProgress(tester, repo);

      final more = find.text(_t('kelajak.progress.more'));
      await _scrollTo(tester, more);
      expect(find.text('Kasbiy qiziqishlar'), findsOneWidget);
      expect(find.text('Career Lab'), findsNothing);

      await tester.tap(more);
      await settleKelajak(tester);

      await _scrollTo(tester, find.text('Career Lab'));
      expect(find.text('Career Lab'), findsOneWidget);
      expect(repo.resultCursors, [null, '2026-10-21T04:05:52.075Z']);
    });

    testWidgets('hali natija yo\'q — hub\'ga taklif', (tester) async {
      await _pumpProgress(tester, kelajakRepo(progress: 'progress_empty'));

      expect(find.text(_t('kelajak.progress.emptyTitle')), findsOneWidget);
      await tester.tap(find.text(_t('kelajak.progress.toHub')));
      await tester.pumpAndSettle();

      expect(find.text('page:${KelajakRoutes.hub}'), findsOneWidget);
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      await _pumpProgress(
        tester,
        kelajakRepo(),
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
