// B02 · Bildirishnomalar: Bugun/Avvalroq guruhlari, «Yangi» belgisi, bosilganda
// o'qilgan deb belgilash va havolaga o'tish yoki to'liq matnni ochish.

import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../features/learning/fake_learning_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

class _FakeNotificationRepo implements BackendNotificationRepository {
  final read = <String>[];

  @override
  Future<bool> markAsRead(String notificationId) async {
    read.add(notificationId);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _items = [
  AppNotification(
    id: 'n1',
    type: NotificationType.studyNudge,
    title: 'Bugungi mashq seni kutmoqda',
    body: 'Matematika · 10 savol',
    createdAt: DateTime(2026, 11, 5, 8, 40),
    isRead: false,
    relatedRoute: '/marker',
  ),
  AppNotification(
    id: 'n2',
    type: NotificationType.voice,
    title: 'Onam xabar yubordi',
    body: 'Darsdan keyin qayerdasan?',
    createdAt: DateTime(2026, 11, 5, 7, 30),
    isRead: true,
  ),
  AppNotification(
    id: 'n3',
    type: NotificationType.achievement,
    title: '+20 DON tasdiqlandi',
    body: '7 kunlik seriya',
    createdAt: DateTime(2026, 11, 4, 18, 0),
    isRead: true,
  ),
];

Future<_FakeNotificationRepo> _pump(WidgetTester tester) async {
  final repo = _FakeNotificationRepo();
  await pumpG5App(
    tester,
    routes: [
      ...buildGrowthV5Routes(),
      GoRoute(
        path: '/marker',
        builder: (_, _) => const Scaffold(body: Text('marker-page')),
      ),
    ],
    initialLocation: GrowthV5Routes.notifications,
    overrides: [
      ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
      notificationsProvider.overrideWith((ref) => Stream.value(_items)),
      backendNotificationRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return repo;
}

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('Bugun va Avvalroq, o\'qilmaganida «Yangi», vaqt va «Kecha»', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('1 ta yangi'), findsOneWidget);
    expect(find.text('BUGUN'), findsOneWidget);
    expect(find.text('AVVALROQ'), findsOneWidget);
    expect(find.text('Yangi'), findsOneWidget);
    expect(find.text('08:40'), findsOneWidget);
    expect(find.text('Kecha'), findsOneWidget);
    expect(find.text('Oilaviy xabar'), findsOneWidget);
  });

  testWidgets(
    'havolali xabar o\'qilgan deb belgilanadi va o\'sha ekranni ochadi',
    (tester) async {
      final repo = await _pump(tester);

      await tester.tap(find.text('Bugungi mashq seni kutmoqda'));
      await settleG5(tester);

      expect(repo.read, ['n1']);
      expect(find.text('marker-page'), findsOneWidget);
    },
  );

  testWidgets('havolasiz xabar to\'liq matnni varaqda ochadi', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Onam xabar yubordi'));
    await settleG5(tester);

    expect(find.text('Darsdan keyin qayerdasan?'), findsOneWidget);
  });
}
