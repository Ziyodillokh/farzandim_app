// I10 · Ilova qulfi: kod xeshi, xato urinishlar va kutish, qayta ochilganda
// holat, avtomatik qulflash; qulf ekrani va «Men › Ilova qulfi» oqimi.

import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/growth/men/lock/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'fake_kirish.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Future<void> _type(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.bySemanticsLabel(d).last);
    await tester.pump();
  }
  await settleG5(tester);
}

void main() {
  group('AppLock', () {
    late MemoryLockStore store;
    late DateTime now;
    AppLock make() => AppLock(store, clock: () => now);

    setUp(() {
      store = MemoryLockStore();
      now = DateTime(2026, 11, 7, 10);
    });

    test('kod xesh bilan saqlanadi; to\'g\'ri kod ochadi', () async {
      final lock = make();
      await lock.setPin('2580');
      expect(store.values.values.join(), isNot(contains('2580')));

      final again = make();
      await again.load();
      expect(again.isLocked, isTrue);
      expect(await again.unlock('1111'), PinCheck.wrong);
      expect(again.isLocked, isTrue);
      expect(await again.unlock('2580'), PinCheck.ok);
      expect(again.isLocked, isFalse);
    });

    test('5 ta xatodan keyin kutish; qayta ochilganda ham saqlanadi', () async {
      final lock = make();
      await lock.setPin('2580');
      for (var i = 0; i < 4; i++) {
        expect(await lock.verify('0000'), PinCheck.wrong);
      }
      expect(await lock.verify('0000'), PinCheck.blocked);
      // Kutish paytida to'g'ri kod ham qabul qilinmaydi.
      expect(await lock.verify('2580'), PinCheck.blocked);

      final reopened = make();
      await reopened.load();
      expect(reopened.blockedUntil, isNotNull);

      now = now.add(const Duration(seconds: 31));
      expect(await reopened.unlock('2580'), PinCheck.ok);
      expect(reopened.blockedUntil, isNull);
    });

    test('fondan qaytganda: belgilangan vaqtdan keyin qulflanadi', () async {
      final lock = make();
      await lock.setPin('2580');
      lock
        ..onBackground()
        ..onForeground();
      expect(lock.isLocked, isFalse, reason: '1 daqiqa o\'tmagan');

      lock.onBackground();
      now = now.add(const Duration(minutes: 2));
      lock.onForeground();
      expect(lock.isLocked, isTrue);

      await lock.unlock('2580');
      await lock.setAutoLock(AutoLock.immediately);
      lock
        ..onBackground()
        ..onForeground();
      expect(lock.isLocked, isTrue);
    });

    test('o\'chirilgach qulf yo\'q', () async {
      final lock = make();
      await lock.setPin('2580');
      await lock.disable();
      await lock.load();
      expect(lock.isEnabled, isFalse);
      expect(lock.isLocked, isFalse);
    });
  });

  group('ekranlar', () {
    setUpAll(setUpG5WidgetTests);
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('qulf ekrani: xato kod, so\'ng to\'g\'risi ochadi', (
      tester,
    ) async {
      final lock = AppLock(MemoryLockStore());
      await lock.setPin('2580');
      await lock.load();
      await pumpG5App(
        tester,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => AppLockGate(
              lock: lock,
              child: const Center(child: Text('Ichki ekran')),
            ),
          ),
        ],
        initialLocation: '/',
        overrides: [
          deviceKeyProvider.overrideWithValue(FakeDeviceKey(available: false)),
        ],
      );
      await settleG5(tester);
      expect(find.text('PIN-kodni kirit'), findsOneWidget);
      // Panel ekran o'rtasida (chapga surilmaydi).
      final center = tester.getCenter(find.bySemanticsLabel('5').last).dx;
      expect(center, moreOrLessEquals(390 / 2, epsilon: 1));

      await _type(tester, '1111');
      expect(find.text('Notoʻgʻri PIN-kod'), findsOneWidget);
      expect(lock.isLocked, isTrue);

      await _type(tester, '2580');
      expect(lock.isLocked, isFalse);
      expect(find.text('PIN-kodni kirit'), findsNothing);
      expect(find.text('Ichki ekran'), findsOneWidget);
    });

    testWidgets('Men › Ilova qulfi: PIN-kod qo\'yish', (tester) async {
      final lock = AppLock(MemoryLockStore());
      await pumpG5App(
        tester,
        routes: buildGrowthV5Routes(),
        initialLocation: GrowthV5Routes.meLock,
        overrides: [
          ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
          appLockProvider.overrideWithValue(lock),
          deviceKeyProvider.overrideWithValue(FakeDeviceKey()),
        ],
      );
      await settleG5(tester);
      await tester.tap(find.text('PIN-kod qoʻyish'));
      await settleG5(tester);

      await _type(tester, '2580');
      expect(find.text('PIN-kodni takrorla'), findsOneWidget);
      await _type(tester, '2581');
      expect(find.text('Kodlar mos kelmadi — qaytadan kirit'), findsOneWidget);
      await _type(tester, '2580');

      expect(lock.isEnabled, isTrue);
      expect(find.text('Ilova qulfi yoqilgan'), findsOneWidget);
    });
  });
}
