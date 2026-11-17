// Maktab widget testlari uchun ilova: tarjimalar (uz), Growth shriftlari,
// soxta maktab manbai va go_router — tarmoq va kamera yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';

/// Testdagi ulangan bola (`schoolAccountProvider`).
const kTestSchoolAccount = 'child-1';

/// `setUpAll`: tarjimalar va shriftlar sozlamasi (bir marta).
Future<void> setUpSchoolWidgetTests() async {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
  await EasyLocalization.ensureInitialized();
}

/// Bugungi holat — `todayJson` ustiga o'zgarishlar.
SchoolToday todayWith(Map<String, Object?> changes) =>
    SchoolToday.tryFromJson({...todayJson, ...changes})!;

/// Bo'sh sahifa — navigatsiya natijasini tekshirish uchun.
GoRoute markerRoute(String path) => GoRoute(
  path: path,
  builder: (_, _) => Scaffold(body: Text('page:$path')),
);

/// Ilovani chizadi va tarjimalar / shriftlar yuklanishini kutadi.
/// [overrides] — qo'shimcha providerlar (masalan, kunlik reja, kitoblar).
Future<void> pumpSchoolApp(
  WidgetTester tester, {
  required FakeSchoolRepository repository,
  required List<RouteBase> routes,
  required String initialLocation,
  Size size = const Size(393, 852),
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
      overrides: [
        schoolRepositoryProvider.overrideWithValue(repository),
        schoolAccountProvider.overrideWithValue(kTestSchoolAccount),
        ...overrides,
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
  await tester.pump(const Duration(milliseconds: 300));
}

/// Growth sahifalaridagi barcha bundle shrift og'irliklari.
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

/// Kamerasiz skaner: [scan] QR matnini "ko'rsatadi".
class FakeScanner {
  ValueChanged<String>? _onCode;

  static const label = 'fake-scanner';

  Widget build(
    BuildContext context,
    ValueChanged<String> onCode,
    Widget overlay,
  ) {
    _onCode = onCode;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        overlay,
        const Align(alignment: Alignment.topCenter, child: Text(label)),
      ],
    );
  }

  void scan(String raw) {
    final onCode = _onCode;
    if (onCode == null) throw StateError('skaner chizilmagan');
    onCode(raw);
  }
}

/// Kiosk QR havolasi.
String kioskLink(String token) => 'parvoz-school://checkin?code=$token';
