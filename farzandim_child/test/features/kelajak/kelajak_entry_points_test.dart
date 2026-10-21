// Kelajak kirish nuqtalari: bosh sahifa kartasi (kunlik savollar holati),
// Testlar sahifasidagi qator va "Rivojlanish"dagi "Kelajak profilim"
// bo'limi. Kelajak mavjud bo'lmasa (server bilmaydi, yosh oraliqdan
// tashqarida, ulanmagan, yuklanmoqda) — hech narsa ko'rinmaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_profile_section.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_tests_entry.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_kelajak_repository.dart';
import 'kelajak_test_app.dart';

/// Ro'yxat chekkasidagi bo'shliq (bo'lim yo'q bo'lsa keyingisi shu yerda).
const _listPadding = 16.0;
const _next = 'next-section';

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

Future<void> _pump(
  WidgetTester tester,
  FakeKelajakRepository repo,
  Widget section, {
  String? account = 'child-1',
  Size size = const Size(393, 852),
  double textScale = 1,
}) => pumpKelajakApp(
  tester,
  repository: repo,
  account: account,
  size: size,
  textScale: textScale,
  initialLocation: '/page',
  routes: [
    GoRoute(
      path: '/page',
      builder: (_, _) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(_listPadding),
          children: [section, const Text(_next)],
        ),
      ),
    ),
    kelajakMarker(KelajakRoutes.hub),
    kelajakMarker(KelajakRoutes.session),
    kelajakMarker(KelajakRoutes.progress),
    kelajakMarker(KelajakRoutes.ageEdit),
  ],
);

void _expectHidden(WidgetTester tester) {
  expect(find.text(_t('kelajak.title')), findsNothing);
  expect(find.text(_t('kelajak.profile.title')), findsNothing);
  expect(tester.getTopLeft(find.text(_next)).dy, _listPadding);
}

FakeKelajakRepository _failing(KelajakErrorCode code) =>
    kelajakRepo()..onOverview = () async => throw KelajakException(code);

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpKelajakWidgetTests);

  group('bosh sahifa kartasi', () {
    testWidgets('server Kelajakni bilmasa — karta ham, bo\'shliq ham yo\'q', (
      tester,
    ) async {
      await _pump(
        tester,
        _failing(KelajakErrorCode.unavailable),
        const KelajakTodayCard(),
      );

      expect(tester.takeException(), isNull);
      _expectHidden(tester);
    });

    testWidgets('yosh oraliqdan tashqarida — yashirin', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_age_out_of_range'),
        const KelajakTodayCard(),
      );

      _expectHidden(tester);
    });

    testWidgets('ulanmagan — so\'rov ham, karta ham yo\'q', (tester) async {
      final repo = kelajakRepo();

      await _pump(tester, repo, const KelajakTodayCard(), account: null);

      _expectHidden(tester);
      expect(repo.overviewLoads, 0);
    });

    testWidgets('yuklanmoqda yoki oflayn — yashirin', (tester) async {
      final pending = Completer<KelajakOverview>();
      final repo = kelajakRepo()..onOverview = () => pending.future;

      await _pump(tester, repo, const KelajakTodayCard());
      _expectHidden(tester);

      pending.completeError(const KelajakException(KelajakErrorCode.network));
      await settleKelajak(tester);
      _expectHidden(tester);
    });

    testWidgets('bugun yangi — savollar soni va "boshlash"', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_ok_fresh'),
        const KelajakTodayCard(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_t('kelajak.title')), findsOneWidget);
      expect(find.text(_t('kelajak.status.new')), findsOneWidget);
      expect(
        find.text(_t('kelajak.home.fresh', {'meta': '10 ta savol · 3 daqiqa'})),
        findsOneWidget,
      );

      await _tapAndSettle(tester, _t('kelajak.home.startDaily'));

      expect(find.text('page:${KelajakRoutes.session}:daily'), findsOneWidget);
    });

    testWidgets('boshlangan — "Davom etish"', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_ok_today_mixed'),
        const KelajakTodayCard(),
      );

      expect(find.text(_t('kelajak.status.inProgress')), findsOneWidget);
      expect(find.text(_t('kelajak.home.unfinished')), findsOneWidget);
      expect(find.text(_t('kelajak.action.continue')), findsOneWidget);
    });

    testWidgets('bajarilgan — natijani ko\'rish; karta hub\'ni ochadi', (
      tester,
    ) async {
      await _pump(tester, kelajakRepo(), const KelajakTodayCard());

      expect(find.text(_t('kelajak.status.completed')), findsOneWidget);
      expect(find.text(_t('kelajak.home.done')), findsOneWidget);
      expect(find.text(_t('kelajak.action.result')), findsOneWidget);

      await _tapAndSettle(tester, _t('kelajak.title'));

      expect(find.text('page:${KelajakRoutes.hub}'), findsOneWidget);
    });

    testWidgets('yosh kiritilmagan — profil sahifasiga', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_age_required'),
        const KelajakTodayCard(),
      );

      expect(find.text(_t('kelajak.home.ageHint')), findsOneWidget);
      expect(find.text(_t('kelajak.status.new')), findsNothing);

      await _tapAndSettle(tester, _t('kelajak.age.requiredAction'));

      expect(find.text('page:${KelajakRoutes.ageEdit}'), findsOneWidget);
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_ok_today_mixed'),
        const KelajakTodayCard(),
        size: const Size(320, 700),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_t('kelajak.action.continue')), findsOneWidget);
    });
  });

  group('Testlar sahifasidagi qator', () {
    testWidgets('mavjud bo\'lsa — holat bilan, hub\'ni ochadi', (tester) async {
      await _pump(tester, kelajakRepo(), const KelajakTestsEntry());

      expect(find.text(_t('kelajak.tests.entryBody')), findsOneWidget);
      expect(find.text(_t('kelajak.status.completed')), findsOneWidget);

      await _tapAndSettle(tester, _t('kelajak.title'));

      expect(find.text('page:${KelajakRoutes.hub}'), findsOneWidget);
    });

    testWidgets('yosh oraliqdan tashqarida — yashirin', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_age_out_of_range'),
        const KelajakTestsEntry(),
      );

      _expectHidden(tester);
    });
  });

  group('"Rivojlanish"dagi "Kelajak profilim"', () {
    testWidgets('profil: qiziqishlar, kuchli tomonlar va o\'sganlar', (
      tester,
    ) async {
      await _pump(tester, kelajakRepo(), const KelajakProfileSection());

      expect(tester.takeException(), isNull);
      expect(find.text(_t('kelajak.profile.title')), findsOneWidget);
      for (final text in [
        'Ijodiy yo‘nalish',
        'Tadqiqotchi yo‘nalish',
        'Ijtimoiy yo‘nalish',
        'Muloqot va o‘zini anglash',
        'Kelajakni rejalashtirish',
        // `progress_multi_day`: o'sgan mavzular va qiziqish.
        'Maktab sifati va darslar',
        'O‘qituvchi bilan munosabat',
        'Ijtimoiy',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // Eng ko'pi 3 ta kuchli tomon.
      expect(find.text('Shaxsiy fazilatlar'), findsNothing);

      await _tapAndSettle(tester, _t('progress.seeAll'));

      expect(find.text('page:${KelajakRoutes.progress}'), findsOneWidget);
    });

    testWidgets('profil hali yo\'q — taklif va hub', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_ok_fresh', progress: 'progress_empty'),
        const KelajakProfileSection(),
      );

      expect(find.text(_t('kelajak.profile.empty')), findsOneWidget);
      expect(find.text(_t('progress.seeAll')), findsNothing);

      await _tapAndSettle(tester, _t('kelajak.action.start'));

      expect(find.text('page:${KelajakRoutes.hub}'), findsOneWidget);
    });

    testWidgets('yosh kiritilmagan — profil sahifasiga', (tester) async {
      await _pump(
        tester,
        kelajakRepo(overview: 'overview_age_required'),
        const KelajakProfileSection(),
      );

      await _tapAndSettle(tester, _t('kelajak.age.requiredAction'));

      expect(find.text('page:${KelajakRoutes.ageEdit}'), findsOneWidget);
    });

    testWidgets('mavjud bo\'lmasa — bo\'lim ham, bo\'shliq ham yo\'q', (
      tester,
    ) async {
      await _pump(
        tester,
        _failing(KelajakErrorCode.unavailable),
        const KelajakProfileSection(),
      );

      _expectHidden(tester);
    });
  });
}
