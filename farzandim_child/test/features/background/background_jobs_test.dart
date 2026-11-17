// BackgroundJobs: xabarlar marshruti, start tarmoqni kutmaydi va cheklovlar
// birinchi, tick takrorlanmasi, internet qaytishi, ishlar bir-biridan
// ajratilgan (xato/osilish boshqasini to'xtatmaydi).

import 'dart:async';

import 'package:farzandim_child/features/app_restrictions/data/services/game_report_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/step_counter_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_sync_service.dart';
import 'package:farzandim_child/features/background/data/services/background_jobs.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:farzandim_child/features/device_info/data/services/device_info_service.dart';
import 'package:farzandim_child/features/location/data/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_restrictions/restriction_fakes.dart';

/// Barcha soxta ishlar chaqiruvlarni shu ro'yxatga yozadi (tartib bilan).
final _log = <String>[];

Future<void> _record(String name) async => _log.add(name);

class _FakeRestrictions implements RestrictionsSyncService {
  Object? tickError;

  @override
  void start({required String childId}) => _log.add('restrictions.start');
  @override
  Future<void> sync() => _record('restrictions.sync');
  @override
  Future<void> onTick() async {
    _log.add('restrictions.tick');
    final error = tickError;
    if (error != null) throw error;
  }

  @override
  Future<void> onScreenOn() => _record('restrictions.screenOn');
  @override
  Future<void> onConnectivityRestored() => _record('restrictions.online');
  @override
  void dispose() => _log.add('restrictions.dispose');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeviceInfo implements DeviceInfoService {
  @override
  Future<void> start({required String parentUid, required String childId}) =>
      _record('deviceInfo.start');
  @override
  Future<void> sendNow() => _record('deviceInfo.sendNow');
  @override
  Future<void> sendIfDue() => _record('deviceInfo.sendIfDue');
  @override
  void stop() => _log.add('deviceInfo.stop');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocation implements LocationService {
  /// Osilib qoladigan start (tarmoqni kutayotgandek).
  final Completer<void> startGate = Completer<void>();

  @override
  Future<void> start({
    required String parentUid,
    required String childId,
    required String childName,
  }) {
    _log.add('location.start');
    return startGate.future;
  }

  @override
  void stop() => _log.add('location.stop');
  @override
  Future<void> onTick() => _record('location.tick');
  @override
  Future<void> onWake() => _record('location.wake');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUsage implements UsageSyncService {
  @override
  Future<void> syncIfDue() => _record('usage.syncIfDue');
  @override
  void dispose() => _log.add('usage.dispose');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGames implements GameReportService {
  @override
  Future<void> check() => _record('games.check');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSteps implements StepCounterService {
  @override
  Future<void> syncIfDue() => _record('steps.syncIfDue');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRestrictions restrictions;
  late _FakeLocation location;
  late StreamController<bool> connectivity;
  late DateTime now;
  late BackgroundJobs jobs;
  var stringsChanged = 0;

  BackgroundJobs build({bool withSteps = false}) => BackgroundJobs(
    childId: 'c1',
    parentUid: 'p1',
    childName: 'Ali',
    restrictions: restrictions,
    ownsRestrictions: true,
    location: location,
    ownsLocation: true,
    deviceInfo: _FakeDeviceInfo(),
    usageSync: _FakeUsage(),
    gameReports: _FakeGames(),
    stepCounter: withSteps ? _FakeSteps() : null,
    flushOfflineBuffer: () => _record('offline.flush'),
    checkUninstallGuard: () => _record('uninstallGuard'),
    connectivity: connectivity.stream,
    connectivityDebounce: Duration.zero,
    onStringsChanged: () async => stringsChanged++,
    clock: () => now,
    isAndroid: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _log.clear();
    stringsChanged = 0;
    restrictions = _FakeRestrictions();
    location = _FakeLocation();
    connectivity = StreamController<bool>.broadcast();
    now = DateTime.utc(2026, 11, 13, 5);
    jobs = build();
  });

  tearDown(() async {
    await jobs.stop();
    await connectivity.close();
  });

  test(
    'start: cheklovlar birinchi, osilgan ish start\'ni to\'xtatmaydi',
    () async {
      await jobs.start().timeout(const Duration(seconds: 2));
      await pumpEventQueue();

      expect(_log.first, 'restrictions.start');
      expect(
        _log,
        containsAll([
          'deviceInfo.start',
          'location.start',
          'usage.syncIfDue',
          'games.check',
          'offline.flush',
          'uninstallGuard',
        ]),
      );
    },
  );

  test(
    'tick: barcha ishlar; 60 s ichidagi ikkinchi tick o\'tkazib yuboriladi',
    () async {
      jobs = build(withSteps: true);
      await jobs.onMessage(ParvozMessages.tick);

      expect(
        _log,
        containsAll([
          'restrictions.tick',
          'deviceInfo.sendIfDue',
          'usage.syncIfDue',
          'games.check',
          'offline.flush',
          'location.tick',
          'steps.syncIfDue',
          'uninstallGuard',
        ]),
      );

      _log.clear();
      now = now.add(const Duration(seconds: 30));
      await jobs.onTick();
      expect(_log, isEmpty);

      now = now.add(const Duration(seconds: 31));
      await jobs.onTick();
      expect(_log, contains('restrictions.tick'));
    },
  );

  test('bir ish xatosi boshqalarini to\'xtatmaydi', () async {
    restrictions.tickError = StateError('buzildi');

    await jobs.onTick();

    expect(
      _log,
      containsAll([
        'restrictions.tick',
        'deviceInfo.sendIfDue',
        'location.tick',
      ]),
    );
  });

  test('screen_on: cheklovlar har safar, qo\'shimchalar 60 s da bir', () async {
    await jobs.onMessage(ParvozMessages.screenOn);
    expect(
      _log,
      containsAll([
        'restrictions.screenOn',
        'deviceInfo.sendIfDue',
        'usage.syncIfDue',
        'games.check',
      ]),
    );

    _log.clear();
    now = now.add(const Duration(seconds: 10));
    await jobs.onScreenOn();
    expect(_log, ['restrictions.screenOn']);
  });

  test('push, location_wake, strings va noma\'lum xabarlar', () async {
    await jobs.onMessage(ParvozMessages.restrictionsSync);
    expect(_log, ['restrictions.sync']);

    _log.clear();
    await jobs.onMessage('restrictions_sync'); // prefikssiz eski shakl
    expect(_log, ['restrictions.sync']);

    _log.clear();
    await jobs.onMessage(ParvozMessages.locationWake);
    expect(_log, containsAll(['location.wake', 'deviceInfo.sendNow']));

    _log.clear();
    await jobs.onMessage(ParvozMessages.strings);
    expect(stringsChanged, 1);

    await jobs.onMessage('parvoz:nimadir');
    expect(_log, isEmpty);
  });

  test('internet qaytishi ("yo\'q → bor") darhol ishlarni boshlaydi', () async {
    await jobs.start();
    await pumpEventQueue();
    _log.clear();

    connectivity.add(true); // birinchi hodisa — faqat holat
    await pumpEventQueue();
    expect(_log, isEmpty);

    connectivity
      ..add(false)
      ..add(true);
    await pumpEventQueue();
    expect(
      _log,
      containsAll([
        'restrictions.online',
        'offline.flush',
        'games.check',
        'deviceInfo.sendIfDue',
        'usage.syncIfDue',
      ]),
    );
  });

  test(
    'stop: egalik qilingan servislar to\'xtaydi, keyin xabarlar e\'tiborsiz',
    () async {
      await jobs.start();
      await pumpEventQueue();
      _log.clear();

      await jobs.stop();
      expect(
        _log,
        containsAll([
          'restrictions.dispose',
          'location.stop',
          'deviceInfo.stop',
        ]),
      );

      _log.clear();
      await jobs.onMessage(ParvozMessages.tick);
      await jobs.onScreenOn();
      expect(_log, isEmpty);
    },
  );

  test(
    '"himoya o\'chirildi" bayrog\'i: xabar ketgachgina tozalanadi',
    () async {
      SharedPreferences.setMockInitialValues({
        'uninstall_guard.deactivated': true,
      });
      final policy = FakeDevicePolicyRepo()..reportOk = false;
      jobs = BackgroundJobs(
        childId: 'c1',
        parentUid: 'p1',
        childName: 'Ali',
        restrictions: restrictions,
        location: location,
        deviceInfo: _FakeDeviceInfo(),
        usageSync: _FakeUsage(),
        gameReports: _FakeGames(),
        flushOfflineBuffer: () => _record('offline.flush'),
        devicePolicyRepo: policy,
        connectivity: connectivity.stream,
        clock: () => now,
        isAndroid: true,
      );

      await jobs.onTick();
      final prefs = await SharedPreferences.getInstance();
      expect(policy.reports, 1);
      expect(prefs.getBool('uninstall_guard.deactivated'), isTrue);

      policy.reportOk = true;
      now = now.add(const Duration(minutes: 5));
      await jobs.onTick();
      expect(policy.reports, 2);
      expect(prefs.getBool('uninstall_guard.deactivated'), isNull);

      now = now.add(const Duration(minutes: 5));
      await jobs.onTick();
      expect(policy.reports, 2);
    },
  );
}
