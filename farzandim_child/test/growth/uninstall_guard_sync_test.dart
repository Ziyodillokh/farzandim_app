// v5 qobig'i «O'chirishni taqiqlash» siyosatini ochilganda va har qaytganda
// qo'llaydi (fn-uninstall-guard-regression): PIN qulfi ochilishini kutadi,
// mehmon akkauntda va ulanmagan qurilmada tegmaydi.

import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/growth/shell/uninstall_guard_sync.dart';
import 'package:farzandim_child/growth/shell/uninstall_guard_syncer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'g5_overrides.dart' show FakeG5Pairing, MemoryLockStore;

const _pin = '2580';

class _Unpaired extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  _Unpaired() : super(const AppPairingState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  final applied = <(bool?, bool)>[];
  late final lock = AppLock(MemoryLockStore());

  late final syncer = UninstallGuardSyncer(
    readPolicy: (childId) async => true,
    isActive: () async => false,
    apply: (shouldProtect, {required allowPrompt}) async {
      applied.add((shouldProtect, allowPrompt));
      return false;
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    bool locked = false,
    bool paired = true,
    DeviceAccount? guest,
  }) async {
    if (locked) {
      await lock.setPin(_pin);
      await lock.load();
    }
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const UninstallGuardSync(child: Text('qobiq')),
        ),
      ],
    );
    addTearDown(router.dispose);
    PairingNotifier pairing() {
      if (paired) return FakeG5Pairing('Aziza');
      return _Unpaired();
    }

    final container = ProviderContainer(
      overrides: [
        routerProvider.overrideWithValue(router),
        appLockProvider.overrideWithValue(lock),
        uninstallGuardEnabledProvider.overrideWithValue(true),
        uninstallGuardSyncerProvider.overrideWithValue(syncer),
        pairingStateProvider.overrideWith((ref) => pairing()),
        if (guest != null) activeGuestProvider.overrideWithValue(guest),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await frames(tester);
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> _leaveAndReturn(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  testWidgets('ochilganda qo\'llanadi, qaytganda yana — dialog bir marta', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(h.applied, [(true, true)]);

    await _leaveAndReturn(tester);
    await h.frames(tester);
    expect(h.applied, [(true, true), (true, false)]);
  });

  testWidgets('PIN qulfi ochilmaguncha kutadi', (tester) async {
    final h = _Harness();
    await h.pump(tester, locked: true);
    expect(h.applied, isEmpty);

    await h.lock.unlock(_pin);
    await h.frames(tester);
    expect(h.applied, [(true, true)]);
  });

  testWidgets('mehmon akkauntda tegmaydi', (tester) async {
    final h = _Harness();
    await h.pump(
      tester,
      guest: const DeviceAccount(childId: 'g', name: 'Mehmon', owner: false),
    );
    await _leaveAndReturn(tester);
    await h.frames(tester);

    expect(h.applied, isEmpty);
  });

  testWidgets('ulanmagan qurilmada tegmaydi', (tester) async {
    final h = _Harness();
    await h.pump(tester, paired: false);

    expect(h.applied, isEmpty);
  });
}
