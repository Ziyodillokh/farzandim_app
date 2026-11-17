// RestrictionsSyncService: oflayn kesh, reload, faqat o'zgarishda yozish,
// grant'lar, unpair himoyasi, bir vaqtda bitta so'rov, backoff va "muddati
// keldimi" mantig'i (tick / ekran).

import 'dart:async';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_snapshot.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'restriction_fakes.dart';

DateTime _tkt(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 5));

RestrictionPlan _cachedPlan(List<String> fullBlocks) => RestrictionPlan(
  fullBlocks: fullBlocks,
  limitEntries: const [],
  policies: const [],
  routines: const [],
  blockAll: false,
  planDay: '2026-11-13',
);

class _Harness {
  final gate = FetchGate();
  late final schedules = FakeScheduleRepo(gate);
  late final limits = FakeAppLimitRepo(gate);
  late final routines = FakeRoutineRepo(gate);
  final policy = FakeDevicePolicyRepo();
  final unlock = FakeUnlockRepo();
  DateTime now = _tkt(2026, 11, 13, 10);
  late SharedPreferences prefs;
  final services = <RestrictionsSyncService>[];

  Future<void> init(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  RestrictionsSyncService build({Duration debounce = Duration.zero}) {
    final service = RestrictionsSyncService(
      scheduleRepo: schedules,
      appLimitRepo: limits,
      routineRepo: routines,
      devicePolicyRepo: policy,
      unlockRepo: unlock,
      clock: () => now,
      clockOffsetMs: () => 0,
      ensureClockLoaded: () async {},
      clockOffsetChanges: const Stream<int>.empty(),
      deviceClock: () => now,
      prefs: () async => prefs,
      locationOn: () async => true,
      debounce: debounce,
    );
    services.add(service);
    return service;
  }

  void dispose() {
    for (final s in services) {
      s.dispose();
    }
  }

  Iterable<String> get restrictionKeys =>
      prefs.getKeys().where((k) => k.startsWith('restriction.'));
}

void main() {
  late _Harness h;

  setUp(() => h = _Harness());
  tearDown(() {
    h.dispose();
    SchoolZoneStore.debugReset();
  });

  test('tarmoq yiqilsa — keshdagi reja qo\'llanadi (fail-closed)', () async {
    await h.init({
      'childId': 'c1',
      RestrictionKeys.planCache: _cachedPlan(['com.cached']).toJsonString(),
    });
    h.limits.result = null;

    h.build().start(childId: 'c1');
    await pumpEventQueue();

    expect(h.prefs.getString(RestrictionKeys.blocked), 'com.cached');
    expect(h.prefs.getString(RestrictionKeys.baseBlocked), 'com.cached');
    expect(h.prefs.getInt(RestrictionKeys.snapshotVersion), 1);
  });

  test('reja hech olinmagan va tarmoq yo\'q — prefs\'ga tegilmaydi', () async {
    await h.init({'childId': 'c1'});
    h.limits.result = null;

    h.build().start(childId: 'c1');
    await pumpEventQueue();

    expect(h.restrictionKeys, isEmpty);
  });

  test(
    'reload: boshqa isolate yozgan reja qayta qo\'llashda ko\'rinadi',
    () async {
      await h.init({'childId': 'c1'});
      h.limits.result = null;
      final service = h.build()..start(childId: 'c1');
      await pumpEventQueue();

      // Boshqa isolate (UI egasi) yangi rejani yozdi — bu nusxa keshida yo'q.
      SharedPreferences.setMockInitialValues({
        'childId': 'c1',
        RestrictionKeys.planCache: _cachedPlan(['com.other']).toJsonString(),
      });
      await service.reapply();

      final fresh = await SharedPreferences.getInstance();
      expect(fresh.getString(RestrictionKeys.blocked), 'com.other');
    },
  );

  test(
    'bir xil reja — kesh va snapshot qayta yozilmaydi; fetchedAt 10 daqiqada bir',
    () async {
      await h.init({'childId': 'c1'});
      h.limits.result = [fullBlock('com.a'), timeLimit('com.yt', 30)];
      final service = h.build()..start(childId: 'c1');
      await pumpEventQueue();
      final raw = h.prefs.getString(RestrictionKeys.planCache)!;
      final fetchedAt = h.prefs.getInt(RestrictionKeys.planFetchedAtMs);

      h.now = h.now.add(const Duration(minutes: 5));
      await service.syncNow();

      expect(raw, isNot(contains('fetchedAt')));
      expect(h.prefs.getString(RestrictionKeys.planCache), raw);
      expect(h.prefs.getInt(RestrictionKeys.planFetchedAtMs), fetchedAt);
      expect(h.prefs.getInt(RestrictionKeys.snapshotVersion), 1);
      expect(h.prefs.getString(RestrictionKeys.limits), 'com.yt:30');

      h.now = h.now.add(const Duration(minutes: 6));
      await service.syncNow();

      expect(
        h.prefs.getInt(RestrictionKeys.planFetchedAtMs),
        h.now.millisecondsSinceEpoch,
      );
      expect(h.prefs.getInt(RestrictionKeys.snapshotVersion), 1);
    },
  );

  test(
    'grant\'lar: faqat APP turidagi faol ruxsatlar "paket:tugash"',
    () async {
      await h.init({'childId': 'c1'});
      final until = h.now.add(const Duration(minutes: 15));
      h.unlock.result = [
        ActiveUnlockGrant(
          expiresAt: until,
          remaining: const Duration(minutes: 15),
          packageName: 'com.game',
          kind: 'APP',
        ),
        ActiveUnlockGrant(
          expiresAt: h.now.add(const Duration(minutes: 30)),
          remaining: const Duration(minutes: 30),
          kind: 'SCREEN_TIME',
        ),
      ];

      h.build().start(childId: 'c1');
      await pumpEventQueue();

      expect(
        h.prefs.getString(RestrictionKeys.grants),
        'com.game:${until.millisecondsSinceEpoch}',
      );
    },
  );

  test('qurilma siyosati: blockUninstall UI uchun saqlanadi', () async {
    await h.init({'childId': 'c1'});
    h.policy.result = (
      blockUnknownSources: true,
      blockAllApps: true,
      blockUninstall: true,
    );

    h.build().start(childId: 'c1');
    await pumpEventQueue();

    expect(RestrictionsSyncService.readBlockUninstall(h.prefs), isTrue);
    expect(h.prefs.getBool(RestrictionKeys.blockUnknown), isTrue);
    expect(h.prefs.getString(RestrictionKeys.baseBlocked), '*');
  });

  test('unpair: childId o\'chirilgach hech narsa qayta yozilmaydi', () async {
    await h.init({'childId': 'c1'});
    h.limits.result = [fullBlock('com.a')];
    final service = h.build()..start(childId: 'c1');
    await pumpEventQueue();
    expect(h.restrictionKeys, isNotEmpty);

    await h.prefs.remove('childId');
    await RestrictionsSyncService.clearEnforcementState(h.prefs);
    await service.syncNow();
    await service.reapply();

    expect(h.restrictionKeys, isEmpty);
  });

  test(
    'bir vaqtda bitta so\'rov: parallel chaqiruvlar bitta fetch\'ga qo\'shiladi',
    () async {
      await h.init({'childId': 'c1'});
      h.gate.close();
      final service = h.build()..start(childId: 'c1');
      await pumpEventQueue();

      unawaited(service.syncNow());
      unawaited(service.syncNow());
      await pumpEventQueue();
      expect(h.schedules.calls, 1);

      h.gate.open();
      await pumpEventQueue();
      expect(h.schedules.calls, 1);
    },
  );

  test(
    'so\'rov paytida kelgan push — tugagach yana bir marta olinadi',
    () async {
      await h.init({'childId': 'c1'});
      h.gate.close();
      final service = h.build()..start(childId: 'c1');
      await pumpEventQueue();

      unawaited(service.sync());
      await pumpEventQueue();
      h.gate.open();
      await pumpEventQueue();

      expect(h.schedules.calls, 2);
    },
  );

  test('push\'lar 2 s oynada bittaga yig\'iladi', () async {
    await h.init({'childId': 'c1'});
    final service = h.build(debounce: const Duration(milliseconds: 50))
      ..start(childId: 'c1');
    await pumpEventQueue();
    final before = h.schedules.calls;

    unawaited(service.sync());
    unawaited(service.sync());
    await service.sync();

    expect(h.schedules.calls, before + 1);
  });

  test('xatodan keyin backoff: tick darhol qayta so\'ramaydi', () async {
    await h.init({'childId': 'c1'});
    h.limits.result = null;
    final service = h.build()..start(childId: 'c1');
    await pumpEventQueue();
    expect(h.schedules.calls, 1);

    await service.onTick();
    expect(h.schedules.calls, 1);

    h.now = h.now.add(const Duration(seconds: 31));
    await service.onTick();
    expect(h.schedules.calls, 2);
  });

  test('tick ≥ 4.5 daq, ekran ≥ 2 daq bo\'lsa tarmoqdan oladi', () async {
    await h.init({'childId': 'c1'});
    final service = h.build()..start(childId: 'c1');
    await pumpEventQueue();
    expect(h.schedules.calls, 1);

    h.now = h.now.add(const Duration(minutes: 1));
    await service.onTick();
    await service.onScreenOn();
    expect(h.schedules.calls, 1);

    h.now = h.now.add(const Duration(minutes: 1));
    await service.onScreenOn();
    expect(h.schedules.calls, 2);

    h.now = h.now.add(const Duration(minutes: 4));
    await service.onTick();
    expect(h.schedules.calls, 2);

    h.now = h.now.add(const Duration(seconds: 31));
    await service.onTick();
    expect(h.schedules.calls, 3);
  });
}
