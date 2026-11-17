// "Kirish ma'lumotlari"ga kirish nuqtalari: marshrut ro'yxatda bor; Bolalarim
// → bola kartasi → "Akkount" varag'idagi tugma va Bola sozlamalaridagi karta
// ekranni shu bolaning id'si bilan ochadi.

import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/child_management/presentation/screens/child_settings_screen.dart';
import 'package:farzandim/features/child_management/presentation/screens/children_management_screen.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'credentials_test_harness.dart';

/// Ochilgan ekran o'rniga: kelgan bola id'sini ko'rsatadi.
GoRoute _credentialsStub() => GoRoute(
  path: AppRoutes.childCredentialsPattern,
  builder: (_, state) => Text('credentials:${state.pathParameters['childId']}'),
);

Future<void> _pump(
  WidgetTester tester, {
  required String initialLocation,
  required List<GoRoute> routes,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 1400);
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        childAvatarUrlProvider.overrideWith((ref, id) async => null),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadUzbekTranslations);

  test('yo`l va marshrut: /child-credentials/:childId', () {
    expect(AppRoutes.childCredentialsPath('kid-1'), '/child-credentials/kid-1');
    final router = GoRouter(routes: buildAppRoutes());
    addTearDown(router.dispose);
    final match = router.configuration.findMatch(
      Uri.parse(AppRoutes.childCredentialsPath('kid-1')),
    );
    expect(match.isError, isFalse);
    expect(match.matches, isNotEmpty);
  });

  testWidgets(
    'Bolalarim → bola kartasi → Akkount varag`i → Kirish ma`lumotlari',
    (tester) async {
      await _pump(
        tester,
        initialLocation: AppRoutes.settingsChildren,
        routes: [
          GoRoute(
            path: AppRoutes.settingsChildren,
            builder: (_, _) => const ChildrenManagementScreen(),
          ),
          _credentialsStub(),
        ],
        overrides: [
          childrenProvider.overrideWith((ref) => Stream.value([testChild()])),
        ],
      );

      await tapText(tester, kChildName);
      expect(find.text(t('childCredentials.entry')), findsOneWidget);
      // Avvalgi tugmalar o'z joyida.
      expect(
        find.text(t('childManagement.account.generateQr')),
        findsOneWidget,
      );
      expect(find.text(t('childManagement.account.reconnect')), findsOneWidget);

      await tapText(tester, t('childCredentials.entry'));

      expect(find.text('credentials:$kChildId'), findsOneWidget);
    },
  );

  testWidgets('Bola sozlamalari: "Kirish ma`lumotlari" kartasi', (
    tester,
  ) async {
    await _pump(
      tester,
      initialLocation: AppRoutes.childSettingsPath(kChildId),
      routes: [
        GoRoute(
          path: AppRoutes.childSettingsPattern,
          builder: (_, state) =>
              ChildSettingsScreen(childId: state.pathParameters['childId']!),
        ),
        _credentialsStub(),
      ],
      overrides: [
        childByIdProvider.overrideWith((ref, id) => testChild()),
        restrictionsProvider.overrideWith(
          (ref, id) => Stream.value(const <AppRestriction>[]),
        ),
        schedulesProvider.overrideWith(
          (ref, id) => Stream.value(const <Schedule>[]),
        ),
        geoZonesProvider.overrideWith(
          (ref, id) => Stream.value(const <GeoZone>[]),
        ),
      ],
    );

    expect(find.text(t('childCredentials.entrySubtitle')), findsOneWidget);

    await tapText(tester, t('childCredentials.entry'));

    expect(find.text('credentials:$kChildId'), findsOneWidget);
  });
}
