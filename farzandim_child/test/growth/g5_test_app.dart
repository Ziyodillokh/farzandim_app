// Growth v5 widget testlari uchun ilova: tarjimalar, v5 shriftlari (Onest +
// Unbounded) va go_router — tarmoqsiz.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `setUpAll`: tarjimalar va shriftlar sozlamasi (bir marta).
Future<void> setUpG5WidgetTests() async {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
  await EasyLocalization.ensureInitialized();
}

/// Ilovani chizadi va tarjimalar / shriftlar yuklanishini kutadi.
Future<GoRouter> pumpG5App(
  WidgetTester tester, {
  required List<RouteBase> routes,
  required String initialLocation,
  Size size = const Size(390, 844),
  double textScale = 1,
  List<Override> overrides = const [],
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
      overrides: overrides,
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

  await tester.runAsync(() async {
    await preloadG5Fonts();
    await tester.pumpWidget(app);
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await GoogleFonts.pendingFonts();
  });
  await settleG5(tester);
  return router;
}

Future<void> settleG5(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> preloadG5Fonts() async {
  for (final w in [FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    GoogleFonts.onest(fontWeight: w);
    GoogleFonts.unbounded(fontWeight: w);
  }
  GoogleFonts.onest(fontWeight: FontWeight.w400);
  await GoogleFonts.pendingFonts();
}
