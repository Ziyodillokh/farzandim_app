// Kelajak widget testlari uchun ilova: tarjimalar (uz), Growth shriftlari,
// soxta Kelajak manbai (haqiqiy server javoblari) va go_router — tarmoqsiz.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_kelajak_repository.dart';
import 'kelajak_fixtures.dart';

/// `setUpAll`: tarjimalar va shriftlar sozlamasi (bir marta).
Future<void> setUpKelajakWidgetTests() async {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
  await EasyLocalization.ensureInitialized();
}

/// Overview / rivojlanish / natijalar fixture'lardan.
FakeKelajakRepository kelajakRepo({
  String overview = 'overview_ok_with_profile',
  String progress = 'progress_multi_day',
}) {
  final repo = FakeKelajakRepository();
  repo.onOverview = () async => KelajakOverview.fromJson(fixture(overview));
  repo.onProgress = () async => KelajakProgress.fromJson(fixture(progress));
  repo.onResults = (before, _) async => KelajakResultsPage.fromJson(
    fixture(before == null ? 'results_page1_limit2' : 'results_page2_limit2'),
  );
  return repo;
}

/// Bo'sh sahifa — navigatsiya natijasini tekshirish uchun.
GoRoute kelajakMarker(String path) => GoRoute(
  path: path,
  builder: (_, state) =>
      Scaffold(body: Text('page:$path${_extra(state.extra)}')),
);

String _extra(Object? extra) => extra == null ? '' : ':$extra';

/// Ilovani chizadi va tarjimalar / shriftlar yuklanishini kutadi.
Future<void> pumpKelajakApp(
  WidgetTester tester, {
  required FakeKelajakRepository repository,
  required List<RouteBase> routes,
  required String initialLocation,
  Size size = const Size(393, 852),
  double textScale = 1,
  String? account = 'child-1',
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  final app = EasyLocalization(
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('uz'),
    startLocale: const Locale('uz'),
    child: ProviderScope(
      overrides: [
        kelajakRepositoryProvider.overrideWithValue(repository),
        kelajakAccountProvider.overrideWithValue(account),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          routerConfig: router,
        ),
      ),
    ),
  );

  // Shriftlar birinchi kadrdan oldin, tarjimalar esa asinxron yuklanadi.
  await tester.runAsync(() async {
    await _preloadFonts();
    await tester.pumpWidget(app);
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await GoogleFonts.pendingFonts();
  });
  await settleKelajak(tester);
}

/// Soxta manba javoblari va animatsiyalar tugashini kutadi.
Future<void> settleKelajak(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _preloadFonts() async {
  for (final w in [FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.montserrat(fontWeight: w);
  }
  for (final w in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.plusJakartaSans(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}
