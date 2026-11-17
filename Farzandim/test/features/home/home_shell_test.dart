// Asosiy karkas: 3 tab (Maktab · Nazorat · Profil), tab almashishi,
// o'qilmagan e'lonlar belgisi; «Qanday boshlaymiz?» — «Keyinroq»
// belgini saqlab Maktab tabiga o'tadi.

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/home/domain/home_landing.dart';
import 'package:farzandim/features/home/presentation/home_shell.dart';
import 'package:farzandim/features/home/presentation/start_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: AppRoutes.start, builder: (_, _) => const StartScreen()),
    GoRoute(
      path: AppRoutes.schoolLink,
      builder: (_, _) => const Text('page:link'),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => HomeShell(navigationShell: shell),
      branches: [
        for (final path in [
          AppRoutes.school,
          AppRoutes.dashboard,
          AppRoutes.profile,
        ])
          StatefulShellBranch(
            routes: [
              GoRoute(path: path, builder: (_, _) => Text('page:$path')),
            ],
          ),
      ],
    ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester,
  String initial, {
  int schoolUnread = 0,
}) async {
  final router = _router(initial);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [schoolTabUnreadProvider.overrideWithValue(schoolUnread)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('uch tab, belgi va tab almashishi', (tester) async {
    await _pump(tester, AppRoutes.school, schoolUnread: 3);

    for (final tab in ['school', 'control', 'profile']) {
      expect(find.text('home.tabs.$tab'), findsOneWidget);
    }
    expect(find.text('home.tabs.inbox'), findsNothing);
    expect(find.text('page:${AppRoutes.school}'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('home.tabs.profile'));
    await tester.pumpAndSettle();
    expect(find.text('page:${AppRoutes.profile}'), findsOneWidget);

    await tester.tap(find.text('home.tabs.control'));
    await tester.pumpAndSettle();
    expect(find.text('page:${AppRoutes.dashboard}'), findsOneWidget);
  });

  testWidgets('«Keyinroq» — belgi saqlanadi va Maktab tabi ochiladi', (
    tester,
  ) async {
    await _pump(tester, AppRoutes.start);
    expect(find.text('home.start.schoolTitle'), findsOneWidget);
    expect(find.text('home.start.phoneTitle'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('home.start.later'), 200);
    await tester.tap(find.text('home.start.later'));
    await tester.pumpAndSettle();

    expect(find.text('page:${AppRoutes.school}'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kHomeStartSeenKey), isTrue);
  });

  testWidgets('maktab tanlansa — kod sahifasi ochiladi', (tester) async {
    await _pump(tester, AppRoutes.start);
    await tester.tap(find.text('home.start.schoolTitle'));
    await tester.pumpAndSettle();
    expect(find.text('page:link'), findsOneWidget);
  });
}
