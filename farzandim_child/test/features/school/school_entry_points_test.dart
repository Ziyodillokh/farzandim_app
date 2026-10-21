// Maktab UI'si faqat bog'langan bolada: bosh sahifa kartasi, Profil
// menyusidagi "Maktabim" va "Maktabim" sahifasi. Bog'lanmagan, server
// funksiyani bilmaydi (404 kodsiz) yoki birinchi yuklash oflayn bo'lsa —
// hech narsa ko'rinmaydi (bosh sahifa avvalgidek).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_menu.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_hub_screen.dart';
import 'package:farzandim_child/features/school/presentation/widgets/attendance_section.dart';
import 'package:farzandim_child/features/school/presentation/widgets/attendance_widgets.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_test_app.dart';

final _late = todayWith({});

/// Ro'yxat chekkasidagi bo'shliq (karta yo'q bo'lsa keyingi bo'lim shu yerda).
const _listPadding = 16.0;

/// Karta ham, uning bo'shlig'i ham yo'q.
void _expectCardHidden(WidgetTester tester) {
  expect(find.byType(AttendanceTimes), findsNothing);
  expect(find.byType(SchoolScanButton), findsNothing);
  expect(tester.getTopLeft(find.text('next-section')).dy, _listPadding);
}

Future<void> _pumpCard(
  WidgetTester tester,
  FakeSchoolRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) => pumpSchoolApp(
  tester,
  repository: repo,
  initialLocation: '/dashboard',
  size: size,
  textScale: textScale,
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (_, _) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(_listPadding),
          children: const [SchoolTodayCard(), Text('next-section')],
        ),
      ),
    ),
    markerRoute(SchoolRoutes.hub),
    markerRoute(SchoolRoutes.checkIn),
  ],
);

Future<void> _pumpMenu(WidgetTester tester, FakeSchoolRepository repo) =>
    pumpSchoolApp(
      tester,
      repository: repo,
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) =>
              Scaffold(body: ListView(children: const [ProfileMenu()])),
        ),
        markerRoute(SchoolRoutes.hub),
      ],
    );

Future<void> _pumpHub(
  WidgetTester tester,
  FakeSchoolRepository repo, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) => pumpSchoolApp(
  tester,
  repository: repo,
  initialLocation: SchoolRoutes.hub,
  size: size,
  textScale: textScale,
  routes: [
    GoRoute(path: SchoolRoutes.hub, builder: (_, _) => const SchoolHubScreen()),
    markerRoute(SchoolRoutes.checkIn),
  ],
);

void main() {
  setUpAll(setUpSchoolWidgetTests);

  group('bosh sahifa kartasi', () {
    testWidgets('bog\'lanmagan bolada karta ham, bo\'shliq ham yo\'q', (
      tester,
    ) async {
      final repo = FakeSchoolRepository();

      await _pumpCard(tester, repo);

      expect(tester.takeException(), isNull);
      _expectCardHidden(tester);
      expect(repo.calls, ['loadToday']);
    });

    testWidgets('server funksiyani bilmasa (404 kodsiz) — yashirin', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(today: _late)
        ..failNext = const SchoolException(SchoolErrorCode.unavailable);

      await _pumpCard(tester, repo);

      _expectCardHidden(tester);
    });

    testWidgets('birinchi yuklash oflayn — yashirin', (tester) async {
      final repo = FakeSchoolRepository(today: _late)
        ..failNext = const SchoolException(SchoolErrorCode.network);

      await _pumpCard(tester, repo);

      _expectCardHidden(tester);
    });

    testWidgets('bog\'langan: maktab, sinf, holat va QR tugmasi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(today: _late);

      await _pumpCard(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.text('Parvoz maktabi'), findsOneWidget);
      expect(find.text('5-A sinf · 08:00–13:25'), findsOneWidget);
      expect(find.text('school.status.late'.tr()), findsOneWidget);
      expect(find.text('08:12'), findsOneWidget);
      // Kelgan, hali ketmagan — keyingi skanerlash chiqish.
      expect(find.text('school.today.scanOut'.tr()), findsOneWidget);
    });

    testWidgets('QR tugmasi skanerlash sahifasini ochadi', (tester) async {
      final repo = FakeSchoolRepository(today: todayWith({'record': null}));

      await _pumpCard(tester, repo);
      await tester.tap(find.text('school.today.scanIn'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('page:${SchoolRoutes.checkIn}'), findsOneWidget);
    });

    testWidgets('karta bosilsa "Maktabim" ochiladi', (tester) async {
      await _pumpCard(tester, FakeSchoolRepository(today: _late));
      await tester.tap(find.text('Parvoz maktabi'));
      await tester.pumpAndSettle();

      expect(find.text('page:${SchoolRoutes.hub}'), findsOneWidget);
    });

    testWidgets('dam olish kuni yoki chiqib ketgan — QR tugmasi yo\'q', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({'record': null, 'schoolDay': false}),
      );

      await _pumpCard(tester, repo);

      expect(find.text('school.status.dayOff'.tr()), findsOneWidget);
      expect(find.byType(SchoolScanButton), findsNothing);
    });

    testWidgets('chiqib ketgan — QR tugmasi yo\'q, ketgan vaqt ko\'rinadi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(
        today: todayWith({
          'record': {
            'status': 'PRESENT',
            'inAt': '07:58',
            'outAt': '13:31',
            'source': 'QR',
          },
        }),
      );

      await _pumpCard(tester, repo);

      expect(find.text('13:31'), findsOneWidget);
      expect(find.byType(SchoolScanButton), findsNothing);
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(today: _late);

      await _pumpCard(tester, repo, size: const Size(320, 700), textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.byType(SchoolScanButton), findsOneWidget);
    });
  });

  group('Profil menyusi', () {
    testWidgets('bog\'lanmagan bolada "Maktabim" yo\'q', (tester) async {
      await _pumpMenu(tester, FakeSchoolRepository());

      expect(find.byType(ProfileMenu), findsOneWidget);
      expect(find.text('school.hub.title'.tr()), findsNothing);
    });

    testWidgets('bog\'langan bolada "Maktabim" birinchi va ochiladi', (
      tester,
    ) async {
      await _pumpMenu(tester, FakeSchoolRepository(today: _late));

      final school = find.text('school.hub.title'.tr());
      expect(school, findsOneWidget);
      final calendar = find.text('profile.resultsCalendar'.tr());
      expect(
        tester.getTopLeft(school).dy,
        lessThan(tester.getTopLeft(calendar).dy),
      );

      await tester.tap(school);
      await tester.pumpAndSettle();

      expect(find.text('page:${SchoolRoutes.hub}'), findsOneWidget);
    });
  });

  group('"Maktabim" sahifasi', () {
    testWidgets('bog\'lanmagan — tushuntirish, davomat yo\'q', (tester) async {
      await _pumpHub(tester, FakeSchoolRepository());

      expect(find.text('school.hub.notLinkedTitle'.tr()), findsOneWidget);
      expect(find.byType(AttendanceSection), findsNothing);
      expect(find.byType(SchoolScanButton), findsNothing);
    });

    testWidgets('bog\'langan — bugungi davomat, yo\'l-yo\'riq va QR', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(today: todayWith({'record': null}));

      await _pumpHub(tester, repo);

      expect(tester.takeException(), isNull);
      expect(find.byType(AttendanceSection), findsOneWidget);
      expect(find.text('Parvoz maktabi'), findsOneWidget);
      expect(find.text('5-A sinf · 1-smena'), findsOneWidget);
      expect(
        find.text('school.today.dateLine'.tr(namedArgs: {'date': '20-oktabr'})),
        findsOneWidget,
      );
      expect(find.text('school.status.notMarked'.tr()), findsOneWidget);
      expect(find.text('school.today.hints.notMarked'.tr()), findsOneWidget);

      await tester.tap(find.text('school.today.scanIn'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('page:${SchoolRoutes.checkIn}'), findsOneWidget);
    });

    testWidgets('oflayn — xato va "Qayta urinish" bilan tiklanadi', (
      tester,
    ) async {
      final repo = FakeSchoolRepository(today: _late)
        ..failNext = const SchoolException(SchoolErrorCode.network);

      await _pumpHub(tester, repo);

      expect(find.text('school.errors.network'.tr()), findsOneWidget);
      await tester.tap(find.text('common.retry'.tr()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AttendanceSection), findsOneWidget);
      // Bugungi holat qayta so'raldi (keyin bo'limlar ham yuklanadi).
      expect(repo.calls.take(2), ['loadToday', 'loadToday']);
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      await _pumpHub(
        tester,
        FakeSchoolRepository(today: _late),
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AttendanceSection), findsOneWidget);
    });
  });
}
