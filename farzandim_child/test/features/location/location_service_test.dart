// LocationService (1.0.20): har doim BITTA oqim (idempotent start, rejim
// almashuvida eski oqim avval yopiladi, isolate'da bitta faol nusxa), stop
// hammasini to'xtatadi, tick faqat nuqta eskirganda bitta balanced fix
// so'raydi, ruxsat keyin berilsa tick oqimni ochadi, wake GPS fix'ni darhol
// yuboradi, platforma sozlamalari va loglarda koordinata yo'qligi.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show AppLifecycleState;

import 'package:farzandim_child/features/location/data/services/location_platform.dart';
import 'package:farzandim_child/features/location/data/services/location_service.dart';
import 'package:farzandim_child/features/location/data/services/location_strategy.dart';
import 'package:farzandim_child/features/location/data/services/location_uploader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lat = 41.311081;
const _lng = 69.240562;
const _mPerDegLat = 6371000 * math.pi / 180;

Position _pos(double northM, DateTime at, {double acc = 10}) => Position(
  latitude: _lat + northM / _mPerDegLat,
  longitude: _lng,
  timestamp: at,
  accuracy: acc,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// geolocator platformasi o'rniga: so'rovlarni yozib boradi, bir vaqtda
/// nechta oqim tinglanayotganini sanaydi. Haqiqiy geolocator kabi oqimni
/// oxirgi tinglovchi chiqmaguncha KESHLAYDI: eski oqim yopilmasdan yangi
/// sozlama so'ralsa — eski oqim qaytadi (qayta tinglash xato beradi).
class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool serviceEnabled = true;
  Position? lastKnown;
  final currentRequests = <LocationSettings?>[];
  final currentResults = <Position>[];
  final streamRequests = <LocationSettings?>[];
  StreamController<Position>? _controller;
  Stream<Position>? _cached;
  int activeListeners = 0;
  int maxActiveListeners = 0;

  /// Hozir tinglanayotgan oqimning HAQIQIY sozlamasi.
  LocationSettings? activeSettings;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentRequests.add(locationSettings);
    if (currentResults.isEmpty) throw TimeoutException("fix yo'q");
    return currentResults.removeAt(0);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamRequests.add(locationSettings);
    final cached = _cached;
    if (cached != null) return cached;
    final controller = StreamController<Position>();
    controller
      ..onListen = () {
        activeListeners++;
        maxActiveListeners = math.max(maxActiveListeners, activeListeners);
        activeSettings = locationSettings;
      }
      ..onCancel = () {
        activeListeners--;
        activeSettings = null;
        _cached = null;
      };
    _controller = controller;
    return _cached = controller.stream;
  }

  void emit(Position p) => _controller!.add(p);

  void emitError(Object error) => _controller!.addError(error);
}

class _FakeUploader implements LocationUploader {
  final posts = <LocationSample>[];

  @override
  Future<void> post({
    required String childId,
    required LocationSample sample,
  }) async => posts.add(sample);
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGeolocator geo;
  late _FakeUploader uploader;
  late List<LocationSample> zoneFixes;
  late DateTime now;
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  LocationService newService() => LocationService(
    uploader: uploader,
    recordZoneFix: (s) async => zoneFixes.add(s),
    clock: () => now,
  );

  Future<void> startService(LocationService service, {String child = 'c1'}) =>
      service.start(parentUid: 'p1', childId: child, childName: 'Bola');

  setUp(() {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;
    uploader = _FakeUploader();
    zoneFixes = [];
    now = DateTime.utc(2026, 11, 14, 10);
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    LocationService.debugResetIsolate();
    debugPrint = originalDebugPrint;
    debugDefaultTargetPlatformOverride = null;
    // Har bir ssenariyda: loglarda koordinata yo'q.
    for (final line in logs) {
      expect(line, isNot(contains('41.3')), reason: line);
      expect(line, isNot(contains('69.2')), reason: line);
    }
  });

  test(
    'start ikki marta — bitta oqim, statsionar (balanced) sozlama',
    () async {
      final service = newService();

      await startService(service);
      await startService(service);
      await _settle();

      expect(geo.streamRequests, hasLength(1));
      expect(geo.activeListeners, 1);
      final settings = geo.activeSettings! as AndroidSettings;
      expect(settings.accuracy, LocationAccuracy.medium);
      expect(settings.distanceFilter, 50);
      expect(settings.intervalDuration, const Duration(minutes: 3));
      expect(settings.useMSLAltitude, isFalse);
      expect(service.streamMode, LocationMode.stationary);
    },
  );

  test('siljish → safar (GPS oqimi), 5 daqiqa harakatsiz → tick statsionarga '
      'qaytaradi; bir vaqtda faqat bitta oqim', () async {
    final service = newService();
    await startService(service);
    await _settle();

    geo.emit(_pos(0, now));
    await _settle();
    now = now.add(const Duration(minutes: 1));
    geo.emit(_pos(300, now));
    await _settle();

    expect(service.streamMode, LocationMode.trip);
    expect(geo.streamRequests, hasLength(2));
    // Haqiqatda tinglanayotgan oqim — GPS sozlamasi (eski oqim keshdan
    // qaytmagan).
    final trip = geo.activeSettings! as AndroidSettings;
    expect(trip.accuracy, LocationAccuracy.high);
    expect(trip.distanceFilter, 20);
    expect(trip.intervalDuration, const Duration(seconds: 20));
    expect(uploader.posts, hasLength(2));

    now = now.add(const Duration(minutes: 6));
    await service.onTick();
    await _settle();

    expect(service.streamMode, LocationMode.stationary);
    expect(geo.streamRequests, hasLength(3));
    expect(
      (geo.activeSettings! as AndroidSettings).accuracy,
      LocationAccuracy.medium,
    );
    expect(geo.activeListeners, 1);
    expect(geo.maxActiveListeners, 1);
    expect(logs.where((l) => l.contains('oqim amali xato')), isEmpty);
  });

  test('stop — oqim yopiladi, keyingi tick hech narsa ochmaydi', () async {
    final service = newService();
    await startService(service);
    await _settle();

    service.stop();
    await _settle();
    await service.onTick();
    await _settle();

    expect(geo.activeListeners, 0);
    expect(geo.streamRequests, hasLength(1));
    expect(service.streamMode, isNull);
  });

  test("ruxsat yo'q — oqim ochilmaydi; ruxsat berilgach tick ochadi", () async {
    geo.permission = LocationPermission.denied;
    final service = newService();

    await startService(service);
    await _settle();
    expect(geo.streamRequests, isEmpty);
    expect(geo.currentRequests, isEmpty);

    geo.permission = LocationPermission.whileInUse;
    await service.onTick();
    await _settle();

    expect(geo.streamRequests, hasLength(1));
    expect(geo.activeListeners, 1);
  });

  test('oqimda ruxsat xatosi — oqim yopiladi, tick ruxsat qaytgach '
      'qayta ochadi', () async {
    final service = newService();
    await startService(service);
    await _settle();

    geo
      ..permission = LocationPermission.denied
      ..emitError(const PermissionDeniedException('denied'));
    await _settle();
    expect(geo.activeListeners, 0);
    expect(service.streamMode, isNull);

    await service.onTick();
    await _settle();
    expect(geo.streamRequests, hasLength(1));

    geo.permission = LocationPermission.always;
    await service.onTick();
    await _settle();
    expect(geo.streamRequests, hasLength(2));
    expect(geo.activeListeners, 1);
  });

  test('tick: nuqta yangi — fix so\'ralmaydi; 10 daqiqadan eski — bitta '
      'balanced fix (15 s)', () async {
    geo.currentResults.add(_pos(0, now));
    final service = newService();
    await startService(service);
    await _settle();

    expect(geo.currentRequests, hasLength(1));
    expect(geo.currentRequests.single!.accuracy, LocationAccuracy.medium);
    expect(geo.currentRequests.single!.timeLimit, const Duration(seconds: 15));
    expect(uploader.posts, hasLength(1));
    expect(zoneFixes, hasLength(1));

    now = now.add(const Duration(minutes: 5));
    await service.onTick();
    await _settle();
    expect(geo.currentRequests, hasLength(1));

    now = now.add(const Duration(minutes: 6));
    geo.currentResults.add(_pos(5, now));
    await service.onTick();
    await _settle();
    expect(geo.currentRequests, hasLength(2));
    expect(geo.currentRequests.last!.accuracy, LocationAccuracy.medium);
    // Joyida, 15 daqiqa o'tmagan — tarixga yuborilmaydi.
    expect(uploader.posts, hasLength(1));
  });

  test('OS keshidagi yangi nuqta bo\'lsa fix so\'ralmaydi', () async {
    geo.lastKnown = _pos(0, now.subtract(const Duration(minutes: 1)));
    final service = newService();

    await startService(service);
    await _settle();

    expect(geo.currentRequests, isEmpty);
    expect(uploader.posts, hasLength(1));
  });

  test('wake: GPS fix siljishsiz ham darhol yuboriladi, 2 daqiqa safar; '
      'takroriy wake ikkinchi fix olmaydi', () async {
    geo.currentResults.add(_pos(0, now));
    final service = newService();
    await startService(service);
    await _settle();
    expect(uploader.posts, hasLength(1));

    now = now.add(const Duration(minutes: 1));
    geo.currentResults.add(_pos(3, now));
    await service.onWake();
    await _settle();

    expect(geo.currentRequests.last!.accuracy, LocationAccuracy.high);
    expect(geo.currentRequests.last!.timeLimit, const Duration(seconds: 20));
    expect(uploader.posts, hasLength(2));
    expect(service.streamMode, LocationMode.trip);
    expect(geo.activeListeners, 1);

    await service.onWake();
    await _settle();
    final highRequests = geo.currentRequests.where(
      (s) => s!.accuracy == LocationAccuracy.high,
    );
    expect(highRequests, hasLength(1));

    // Harakatsiz — 2 daqiqadan keyin tick statsionar (balanced) oqimga.
    now = now.add(const Duration(minutes: 3));
    await service.onTick();
    await _settle();
    expect(service.streamMode, LocationMode.stationary);
    expect(
      (geo.activeSettings! as AndroidSettings).accuracy,
      LocationAccuracy.medium,
    );
    expect(geo.maxActiveListeners, 1);
  });

  test('sendWakeFix — faol nusxa bo\'lsa unga uzatiladi', () async {
    final service = newService();
    await startService(service);
    await _settle();

    geo.currentResults.add(_pos(0, now));
    await LocationService.sendWakeFix();
    await _settle();

    expect(geo.currentRequests.last!.accuracy, LocationAccuracy.high);
    expect(uploader.posts, hasLength(1));
    expect(geo.activeListeners, 1);
  });

  test("start qilinmagan nusxa (FCM fon engine) wake: juftlik har safar "
      "prefs'dan, oqim ochilmaydi", () async {
    SharedPreferences.setMockInitialValues({
      'parentUid': 'p1',
      'childId': 'c1',
    });
    final service = newService();
    geo.currentResults.add(_pos(0, now));

    await service.onWake();
    await _settle();
    expect(geo.streamRequests, isEmpty);
    expect(uploader.posts, hasLength(1));
    expect(zoneFixes, hasLength(1));

    // Unpair: prefs'da juftlik yo'q — eski id bilan yuborilmaydi.
    SharedPreferences.setMockInitialValues({});
    now = now.add(const Duration(minutes: 5));
    geo.currentResults.add(_pos(0, now));
    await service.onWake();
    await _settle();
    expect(uploader.posts, hasLength(1));
  });

  test("isolate'da ikkinchi nusxa start — birinchisi to'xtaydi, tick faol "
      'nusxaga uzatiladi', () async {
    final first = newService();
    final second = newService();

    await startService(first);
    await _settle();
    await startService(second);
    await _settle();

    expect(geo.activeListeners, 1);
    expect(geo.maxActiveListeners, 1);
    expect(first.streamMode, isNull);
    expect(second.streamMode, LocationMode.stationary);

    now = now.add(const Duration(minutes: 11));
    final before = geo.currentRequests.length;
    await first.onTick();
    await _settle();
    expect(geo.currentRequests, hasLength(before + 1));
  });

  test('yangi juftlik — oqim va holat qaytadan, baribir bitta oqim', () async {
    final service = newService();
    await startService(service);
    await _settle();

    await startService(service, child: 'c2');
    await _settle();

    expect(geo.streamRequests, hasLength(2));
    expect(geo.activeListeners, 1);
    expect(geo.maxActiveListeners, 1);
  });

  test("hudud nuqtasi: joyida tez-tez kelgan nuqtalar 60 s'da bir marta "
      'yoziladi', () async {
    final service = newService();
    await startService(service);
    await _settle();

    for (var i = 0; i < 5; i++) {
      geo.emit(_pos(i * 2.0, now));
      await _settle();
      now = now.add(const Duration(seconds: 10));
    }

    expect(zoneFixes, hasLength(1));
  });

  test('iOS: AppleSettings — fon yangilanishi yoqiq, avto-pauza o\'chiq', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final stationary =
        LocationPlatform.settingsFor(LocationMode.stationary) as AppleSettings;
    final trip =
        LocationPlatform.settingsFor(LocationMode.trip) as AppleSettings;

    expect(stationary.accuracy, LocationAccuracy.medium);
    expect(stationary.distanceFilter, 50);
    expect(stationary.allowBackgroundLocationUpdates, isTrue);
    expect(stationary.pauseLocationUpdatesAutomatically, isFalse);
    expect(trip.accuracy, LocationAccuracy.high);
    expect(trip.distanceFilter, 20);
    expect(trip.allowBackgroundLocationUpdates, isTrue);
    expect(trip.pauseLocationUpdatesAutomatically, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS fonda "while in use" — oqim qayta ochilmaydi (fon joylashuvi '
      'yo\'qolmasin); "Har doim" bo\'lsa tick almashtiradi', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final service = newService();
    await startService(service);
    await _settle();

    geo.emit(_pos(0, now));
    await _settle();
    now = now.add(const Duration(minutes: 1));
    geo.emit(_pos(300, now));
    await _settle();

    expect(service.tracker.mode, LocationMode.trip);
    expect(service.streamMode, LocationMode.stationary);
    expect(geo.streamRequests, hasLength(1));

    geo.permission = LocationPermission.always;
    await service.onTick();
    await _settle();

    expect(service.streamMode, LocationMode.trip);
    expect(
      (geo.activeSettings! as AppleSettings).accuracy,
      LocationAccuracy.high,
    );
    expect(geo.maxActiveListeners, 1);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    debugDefaultTargetPlatformOverride = null;
  });
}
