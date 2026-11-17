// «Ruxsat so'rash» cold start (fn-unlock-request-lost-cold-start): native
// kutilayotgan so'rov /splash va PIN qulfi o'tmaguncha olinmaydi; modal tayyor
// navigatorda ochiladi va splash'ning go()'si uni yopib yubormaydi.

import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/unlock_request_bridge.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/shell_ready_gate.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/unlock_request_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/widgets/unlock_request_modal.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'g5_overrides.dart' show MemoryLockStore;

const _pin = '2580';

/// Native kanal o'rniga: `consumePendingUnlock` necha marta so'ralganini sanaydi.
class _FakeBridge extends UnlockRequestBridge {
  _FakeBridge() : super((_) async {});

  int checks = 0;

  @override
  Future<void> checkPending() async => checks++;
}

class _FakeRepo implements BackendUnlockRequestRepository {
  final sent = <String?>[];

  @override
  Future<bool> createRequest({
    required String kind,
    String? packageName,
    int? requestedMinutes,
    String? reason,
  }) async {
    sent.add(packageName);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AppLock> _lock({required bool locked}) async {
  final lock = AppLock(MemoryLockStore());
  if (locked) {
    await lock.setPin(_pin);
    await lock.load(); // kod bor — ilova qulflangan holda ochiladi
  }
  return lock;
}

GoRouter _router() {
  final router = GoRouter(
    initialLocation: kSplashLocation,
    routes: [
      GoRoute(path: kSplashLocation, builder: (_, _) => const Text('splash')),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

/// ChildApp kabi: ildizda `unlockPendingCheckProvider` kuzatiladi.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required GoRouter router,
  required AppLock lock,
  _FakeBridge? bridge,
  _FakeRepo? repo,
}) async {
  final container = ProviderContainer(
    overrides: [
      routerProvider.overrideWithValue(router),
      appLockProvider.overrideWithValue(lock),
      if (bridge != null) unlockRequestBridgeProvider.overrideWithValue(bridge),
      if (repo != null)
        backendUnlockRequestRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Consumer(
          builder: (context, ref, _) {
            if (bridge != null) ref.watch(unlockPendingCheckProvider);
            return child ?? const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('ShellReadyGate', () {
    testWidgets('splash va qulf paytida yopiq, keyin ochiladi', (tester) async {
      final router = _router();
      final lock = await _lock(locked: true);
      final container = await _pump(tester, router: router, lock: lock);
      final gate = container.read(shellReadyGateProvider);

      var opened = false;
      gate.waitUntilReady().then((ok) => opened = ok);
      await _frames(tester);
      expect(gate.isReady, isFalse);
      expect(opened, isFalse);

      router.go('/home');
      await _frames(tester);
      expect(gate.isReady, isFalse, reason: 'PIN qulfi hali yopiq');
      expect(opened, isFalse);

      await lock.unlock(_pin);
      await _frames(tester);
      expect(gate.isReady, isTrue);
      expect(opened, isTrue);
    });

    testWidgets('konteyner yopilsa kutish bekor bo\'ladi', (tester) async {
      final router = _router();
      final lock = await _lock(locked: false);
      final container = await _pump(tester, router: router, lock: lock);
      final gate = container.read(shellReadyGateProvider);

      bool? result;
      gate.waitUntilReady().then((ok) => result = ok);
      gate.dispose();
      await tester.pump();
      expect(result, isFalse);
    });
  });

  group('kutilayotgan so\'rov', () {
    testWidgets('/splash paytida native so\'rov olinmaydi', (tester) async {
      final bridge = _FakeBridge();
      final router = _router();
      await _pump(
        tester,
        router: router,
        lock: await _lock(locked: false),
        bridge: bridge,
      );

      await _frames(tester);
      expect(bridge.checks, 0);

      router.go('/home');
      await _frames(tester);
      expect(bridge.checks, 1);

      // Bir martalik: keyingi navigatsiyalar qayta so'ramaydi.
      router.go(kSplashLocation);
      await _frames(tester);
      router.go('/home');
      await _frames(tester);
      expect(bridge.checks, 1);
    });

    testWidgets('PIN qulfi ochilmaguncha olinmaydi', (tester) async {
      final bridge = _FakeBridge();
      final router = _router();
      final lock = await _lock(locked: true);
      await _pump(tester, router: router, lock: lock, bridge: bridge);

      router.go('/home');
      await _frames(tester);
      expect(bridge.checks, 0);

      await lock.unlock(_pin);
      await _frames(tester);
      expect(bridge.checks, 1);
    });

    testWidgets(
      'splash paytida kelgan so\'rov modalni yangi sahifada ochadi va yuboradi',
      (tester) async {
        final repo = _FakeRepo();
        final router = _router();
        final container = await _pump(
          tester,
          router: router,
          lock: await _lock(locked: false),
          repo: repo,
        );

        // Native so'rov ilova hali /splash'da turganda keldi.
        final flow = container.read(unlockRequestFlowProvider);
        final done = flow(packageName: 'com.example.game');
        await _frames(tester);
        expect(find.byType(UnlockRequestModal), findsNothing);

        // Splash keyingi ekranga o'tdi — modal shundan keyin ochiladi va
        // sahifa almashuvi bilan yopilib ketmaydi.
        router.go('/home');
        await _frames(tester);
        expect(find.text('home'), findsOneWidget);
        expect(find.byType(UnlockRequestModal), findsOneWidget);
        await _frames(tester);
        expect(find.byType(UnlockRequestModal), findsOneWidget);

        await tester.tap(find.byIcon(Icons.send_rounded));
        await _frames(tester);
        await done;
        expect(repo.sent, ['com.example.game']);
        expect(find.byType(UnlockRequestModal), findsNothing);
      },
    );
  });
}
