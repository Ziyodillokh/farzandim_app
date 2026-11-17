// Bola "parolni unutdim" dedi: push (CHILD_RECOVERY_REQUEST, `childId`) shu
// bolaning "Kirish ma'lumotlari" ekranini ochadi (orqaga — dashboard);
// bola noma'lum bo'lsa — bildirishnomalar; bildirishnoma sahifasida tugma bor;
// ilova ochiq bo'lsa so'rovlar ro'yxati yangilanadi.

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim/features/notifications/presentation/screens/notification_detail_screen.dart';
import 'package:farzandim/features/school/presentation/school_push.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'credentials_test_harness.dart';

AppNotification _push(String type, {Map<String, dynamic> data = const {}}) =>
    AppNotification.fromRemoteMessage(
      RemoteMessage(
        messageId: 'm-$type',
        data: {'type': type, ...data},
        notification: const RemoteNotification(
          title: 'Parol tiklash',
          body: 'So`rov keldi',
        ),
      ),
    );

AppNotification _recovery({String childId = 'kid-1'}) =>
    _push('CHILD_RECOVERY_REQUEST', data: {'childId': childId});

GoRouter _router() => GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, _) => const Text('dashboard'),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (_, _) => const Text('notifications'),
    ),
    GoRoute(
      path: AppRoutes.childCredentialsPattern,
      builder: (_, state) =>
          Text('credentials:${state.pathParameters['childId']}'),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUzbekTranslations);

  group('push bosilganda', () {
    testWidgets('shu bolaning "Kirish ma`lumotlari" ekrani ochiladi', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      handleFcmTap(_recovery(), router);
      await tester.pumpAndSettle();

      expect(find.text('credentials:kid-1'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.childCredentialsPath('kid-1'),
      );

      // Orqaga — dashboard (stek bo'sh qolmaydi).
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsOneWidget);
    });

    testWidgets('bola noma`lum — bildirishnomalar ro`yxati', (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      handleFcmTap(_push('CHILD_RECOVERY_REQUEST'), router);
      await tester.pumpAndSettle();

      expect(find.text('notifications'), findsOneWidget);
    });

    test('maktab push`i emas: maktab marshruti ham, tugma ham yo`q', () {
      expect(schoolRouteFor(_recovery()), isNull);
      expect(schoolPushTarget(_recovery()), isNull);
    });
  });

  group('bildirishnoma sahifasi', () {
    Future<GoRouter> pumpDetail(
      WidgetTester tester,
      AppNotification notification,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 1400);
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/detail',
        routes: [
          GoRoute(
            path: '/detail',
            builder: (_, _) =>
                NotificationDetailScreen(notification: notification),
          ),
          GoRoute(
            path: AppRoutes.childCredentialsPattern,
            builder: (_, state) =>
                Text('credentials:${state.pathParameters['childId']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('"Kirish ma`lumotlarini ochish" tugmasi ekranni ochadi', (
      tester,
    ) async {
      await pumpDetail(tester, _recovery());
      final label = t('notifications.actions.openCredentials');

      expect(find.text(label), findsOneWidget);
      await tapText(tester, label);

      expect(find.text('credentials:kid-1'), findsOneWidget);
    });

    testWidgets('bola noma`lum bo`lsa tugma yo`q', (tester) async {
      await pumpDetail(tester, _push('CHILD_RECOVERY_REQUEST'));

      expect(
        find.text(t('notifications.actions.openCredentials')),
        findsNothing,
      );
    });
  });

  group('ilova ochiq: ro`yxatni yangilash', () {
    test('shu bolaning so`rovlar provayderi yangilanadi', () {
      final invalidated = <Object>[];

      refreshForCredentialsPush(_recovery(), invalidated.add);

      expect(invalidated, [childRecoveryRequestsProvider('kid-1')]);
    });

    test('boshqa bola va boshqa turdagi push tegmaydi', () {
      final invalidated = <Object>[];

      refreshForCredentialsPush(
        _push('CHILD_RECOVERY_REQUEST'),
        invalidated.add,
      );
      refreshForCredentialsPush(
        _push('SCHOOL_ANNOUNCEMENT', data: {'childId': 'kid-1'}),
        invalidated.add,
      );
      refreshForCredentialsPush(
        _push('sos', data: {'childId': 'kid-1'}),
        invalidated.add,
      );

      expect(invalidated, isEmpty);
    });
  });
}
