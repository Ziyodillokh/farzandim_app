// ─────────────────────────────────────────────────────────────────────
// BackgroundJobs — barcha fon ishlari uchun YAGONA rejalashtiruvchi
// ─────────────────────────────────────────────────────────────────────
//
// Bitta egasi bor: Android'da foreground service isolate'i
// (ChildBackgroundTaskHandler); iOS'da va FGS ishlamayotgan Android'da —
// UI isolate (5 daqiqalik Timer + ilova qaytishi). Ikki isolate bir ishni
// takrorlamaydi: UI hodisalarni FGS'ga `sendDataToTask` bilan uzatadi.
//
// Doimiy so'rov (poll) YO'Q — faqat hodisalar va bitta 5 daqiqalik tick:
//   start()        cheklovlar BIRINCHI (keshdagi reja darhol, tarmoq fonda),
//                  qolganlari kutilmaydi (har biri vaqt chegarasi bilan) —
//                  onStart hech qachon tarmoqni kutib qolmaydi;
//   onTick()       cheklovlar (≥ 4.5 daq bo'lsa tarmoq), heartbeat, ilovalar
//                  statistikasi, o'yin xabarlari, oflayn bufer, joylashuv,
//                  qadamlar, "o'chirishdan himoya" bayrog'i;
//   onScreenOn()   cheklovlar darhol qayta qo'llanadi (+ tarmoq ≥ 2 daq);
//   onMessage()    'parvoz:*' xabarlari (qarang ParvozMessages);
//   onConnectivityRestored()  internet qaytdi.
// Bir ishning xatosi yoki osilishi boshqalarini to'xtatmaydi.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/game_report_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/step_counter_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/uninstall_protection_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_sync_service.dart';
import 'package:farzandim_child/features/background/data/services/background_telemetry.dart';
import 'package:farzandim_child/features/background/data/services/job_timing.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:farzandim_child/features/device_info/data/services/device_info_service.dart';
import 'package:farzandim_child/features/location/data/services/location_service.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

typedef _Job = ({String name, Future<void> Function() run});

class BackgroundJobs {
  /// Bo'sh (null) bog'liqliklar platformaga qarab o'zi yaratiladi va
  /// BackgroundJobs ularga EGA bo'ladi (start/stop). Tashqaridan berilgan
  /// [restrictions] / [location] — egasi chaqiruvchi (faqat hodisalar
  /// uzatiladi), [ownsRestrictions] / [ownsLocation] bilan o'zgartirish mumkin.
  BackgroundJobs({
    required this.childId,
    required this.parentUid,
    required this.childName,
    RestrictionsSync? restrictions,
    bool? ownsRestrictions,
    LocationService? location,
    bool? ownsLocation,
    DeviceInfoService? deviceInfo,
    UsageSyncService? usageSync,
    GameReportService? gameReports,
    StepCounterService? stepCounter,
    Future<void> Function()? flushOfflineBuffer,
    Future<void> Function()? checkUninstallGuard,
    BackendDevicePolicyRepository? devicePolicyRepo,
    Stream<bool>? connectivity,
    Future<void> Function()? onStringsChanged,
    DateTime Function()? clock,
    Duration connectivityDebounce = const Duration(seconds: 3),
    bool? isAndroid,
  }) : _isAndroid = isAndroid ?? PlatformCapabilities.hasAndroidControls,
       _ownsRestrictions = ownsRestrictions ?? restrictions == null,
       _ownsLocation = ownsLocation ?? location == null,
       _injectedRestrictions = restrictions,
       _injectedLocation = location,
       _injectedDeviceInfo = deviceInfo,
       _injectedUsageSync = usageSync,
       _injectedGameReports = gameReports,
       _stepCounter = stepCounter,
       _injectedFlush = flushOfflineBuffer,
       _injectedUninstallCheck = checkUninstallGuard,
       _injectedPolicyRepo = devicePolicyRepo,
       _connectivity = connectivity,
       _onStringsChanged = onStringsChanged,
       _clock = clock ?? DateTime.now,
       _connectivityDebounce = connectivityDebounce;

  final String childId;
  final String parentUid;
  final String childName;

  /// Ikki tick (native alarm + plagin repeat) shu oraliqda kelsa — bittasi.
  static const minTickGap = Duration(seconds: 60);

  /// Ekran yoqilishidagi qo'shimcha ishlar (heartbeat, statistika, o'yin) —
  /// ko'pi bilan shu oraliqda bir (cheklovlar har safar darhol).
  static const screenOnExtrasGap = Duration(seconds: 60);

  static const _jobTimeout = Duration(seconds: 60);
  static const _flushTimeout = Duration(minutes: 2);

  final bool _isAndroid;
  final bool _ownsRestrictions;
  final bool _ownsLocation;
  final RestrictionsSync? _injectedRestrictions;
  final LocationService? _injectedLocation;
  final DeviceInfoService? _injectedDeviceInfo;
  final UsageSyncService? _injectedUsageSync;
  final GameReportService? _injectedGameReports;
  final StepCounterService? _stepCounter;
  final Future<void> Function()? _injectedFlush;
  final Future<void> Function()? _injectedUninstallCheck;
  final BackendDevicePolicyRepository? _injectedPolicyRepo;
  final Stream<bool>? _connectivity;
  final Future<void> Function()? _onStringsChanged;
  final DateTime Function() _clock;

  /// Tarmoq o'zgarishi "tebranishi" (Wi-Fi ↔ mobil) bitta hodisaga.
  final Duration _connectivityDebounce;

  // Standart bog'liqliklar — kerak bo'lganda yaratiladi (bitta umumiy Dio).
  late final Dio _dio = createBackendDio(TokenStorage());
  late final BackendDevicePolicyRepository _policyRepo =
      _injectedPolicyRepo ?? BackendDevicePolicyRepository(dio: _dio);

  late final RestrictionsSync? _restrictions =
      _injectedRestrictions ??
      (_isAndroid
          ? RestrictionsSyncService(
              scheduleRepo: BackendScheduleRepository(dio: _dio),
              appLimitRepo: BackendAppLimitRepository(dio: _dio),
              routineRepo: BackendRoutineRepository(dio: _dio),
              devicePolicyRepo: _policyRepo,
              unlockRepo: BackendUnlockRequestRepository(dio: _dio),
            )
          : null);

  late final LocationService _location = _injectedLocation ?? LocationService();

  late final DeviceInfoService _deviceInfo =
      _injectedDeviceInfo ?? DeviceInfoService(dio: _dio);

  late final UsageSyncService? _usageSync =
      _injectedUsageSync ??
      (_isAndroid
          ? UsageSyncService(
              backendRepo: BackendInstalledAppsRepository(dio: _dio),
              statsService: UsageStatsService(),
              childId: childId,
            )
          : null);

  late final GameReportService? _gameReports =
      _injectedGameReports ??
      (_isAndroid ? GameReportService(childId: childId, dio: _dio) : null);

  late final Future<void> Function() _flushOfflineBuffer =
      _injectedFlush ?? OfflineBuffer().flush;

  /// Internet qaytganda kutish (backoff) o'tkazib yuboriladi — aks holda
  /// to'plangan nuqtalar 30 daqiqagacha kutib qolardi.
  late final Future<void> Function() _flushOfflineBufferNow =
      _injectedFlush ?? () => OfflineBuffer().flush(ignoreBackoff: true);

  late final Future<void> Function()? _checkUninstallGuard =
      _injectedUninstallCheck ?? (_isAndroid ? _reportUninstallGuard : null);

  bool _isStarted = false;
  bool _isStopped = false;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _connectivityTimer;
  bool? _wasOnline;
  DateTime? _lastTickAt;
  DateTime? _lastScreenOnExtrasAt;
  Future<void>? _tickInFlight;

  RestrictionsSyncService? get _androidRestrictions {
    final r = _restrictions;
    return r is RestrictionsSyncService ? r : null;
  }

  /// Fon ishlari boshlanishi. Tarmoqni KUTMAYDI.
  Future<void> start() async {
    if (_isStarted || _isStopped) return;
    _isStarted = true;
    _subscribeConnectivity();
    // Saqlangan soat siljishi (mahalliy o'qish) — oynalar va o'yin vaqti
    // birinchi daqiqadanoq ishonchli soatda.
    await _guard(
      'clock.load',
      TrustedClock.ensureLoaded,
      timeout: const Duration(seconds: 5),
    );
    // 1) Cheklovlar birinchi: keshdagi reja darhol (mahalliy), tarmoq fonda.
    if (_ownsRestrictions) _restrictions?.start(childId: childId);
    // 2) Qolganlari — kutilmaydi.
    _fire(
      'deviceInfo.start',
      () => _deviceInfo.start(parentUid: parentUid, childId: childId),
    );
    if (_ownsLocation) {
      _fire(
        'location.start',
        () => _location.start(
          parentUid: parentUid,
          childId: childId,
          childName: childName,
        ),
      );
    }
    final usage = _usageSync;
    if (usage != null) _fire('usage.start', usage.syncIfDue);
    final games = _gameReports;
    if (games != null) _fire('games.start', games.check);
    _fire('offline.start', _flushOfflineBuffer, timeout: _flushTimeout);
    final uninstall = _checkUninstallGuard;
    if (uninstall != null) _fire('uninstallGuard.start', uninstall);
  }

  Future<void> stop() async {
    if (_isStopped) return;
    _isStopped = true;
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    if (!_isStarted) return;
    if (_ownsRestrictions) _restrictions?.dispose();
    if (_ownsLocation) _location.stop();
    _deviceInfo.stop();
    if (_injectedUsageSync == null) _usageSync?.dispose();
  }

  /// 5 daqiqalik tick (native alarm `parvoz:tick` yoki zaxira repeat).
  Future<void> onTick() {
    if (_isStopped) return Future<void>.value();
    final running = _tickInFlight;
    if (running != null) return running;
    final now = _clock();
    final last = _lastTickAt;
    if (last != null && !isDue(last, now, minTickGap)) {
      return Future<void>.value();
    }
    _lastTickAt = now;
    final restrictions = _androidRestrictions;
    final usage = _usageSync;
    final games = _gameReports;
    final steps = _stepCounter;
    final uninstall = _checkUninstallGuard;
    final run = _runAll([
      if (restrictions != null)
        (name: 'restrictions.tick', run: restrictions.onTick),
      (name: 'deviceInfo.tick', run: _deviceInfo.sendIfDue),
      if (usage != null) (name: 'usage.tick', run: usage.syncIfDue),
      if (games != null) (name: 'games.tick', run: games.check),
      (name: 'offline.tick', run: _flushOfflineBuffer),
      (name: 'location.tick', run: _location.onTick),
      if (steps != null) (name: 'steps.tick', run: steps.syncIfDue),
      if (uninstall != null) (name: 'uninstallGuard.tick', run: uninstall),
    ]).whenComplete(() => _tickInFlight = null);
    _tickInFlight = run;
    return run;
  }

  /// Ekran yoqildi / qulf ochildi.
  Future<void> onScreenOn() {
    if (_isStopped) return Future<void>.value();
    final restrictions = _androidRestrictions;
    final now = _clock();
    final hasExtras = isDue(_lastScreenOnExtrasAt, now, screenOnExtrasGap);
    if (hasExtras) _lastScreenOnExtrasAt = now;
    final usage = _usageSync;
    final games = _gameReports;
    return _runAll([
      if (restrictions != null)
        (name: 'restrictions.screenOn', run: restrictions.onScreenOn),
      if (hasExtras) ...[
        // Hudud qarori uchun nuqta yangi bo'lsin (yangi bo'lsa — arzon no-op);
        // yangi nuqta yozilsa cheklov SchoolZoneStore tinglovchisi orqali qayta qo'llanadi.
        (name: 'location.screenOn', run: _location.onTick),
        (name: 'deviceInfo.screenOn', run: _deviceInfo.sendIfDue),
        if (usage != null) (name: 'usage.screenOn', run: usage.syncIfDue),
        if (games != null) (name: 'games.screenOn', run: games.check),
      ],
    ]);
  }

  /// Native / UI isolate xabari ('parvoz:*'; prefikssiz shakli ham qabul).
  Future<void> onMessage(String type) {
    if (_isStopped) return Future<void>.value();
    final message = type.startsWith('parvoz:') ? type : 'parvoz:$type';
    switch (message) {
      case ParvozMessages.tick:
        return onTick();
      case ParvozMessages.screenOn:
        return onScreenOn();
      case ParvozMessages.restrictionsSync:
        final restrictions = _restrictions;
        if (restrictions == null) return Future<void>.value();
        return _guard('restrictions.push', restrictions.sync);
      case ParvozMessages.locationWake:
        return _runAll([
          (name: 'location.wake', run: _location.onWake),
          (name: 'deviceInfo.wake', run: _deviceInfo.sendNow),
        ]);
      case ParvozMessages.strings:
        final onStrings = _onStringsChanged;
        if (onStrings == null) return Future<void>.value();
        return _guard('strings', onStrings);
      default:
        debugPrint('[BackgroundJobs] noma\'lum xabar: $type');
        return Future<void>.value();
    }
  }

  /// Internet qaytdi: kutib turgan ishlar darhol.
  Future<void> onConnectivityRestored() {
    if (_isStopped) return Future<void>.value();
    final restrictions = _androidRestrictions;
    final usage = _usageSync;
    final games = _gameReports;
    return _runAll([
      if (restrictions != null)
        (name: 'restrictions.online', run: restrictions.onConnectivityRestored),
      (name: 'offline.online', run: _flushOfflineBufferNow),
      if (games != null) (name: 'games.online', run: games.check),
      (name: 'deviceInfo.online', run: _deviceInfo.sendIfDue),
      if (usage != null) (name: 'usage.online', run: usage.syncIfDue),
    ]);
  }

  /// Native `onDisabled` qo'ygan bayroq → ota-onaga xabar; bayroq faqat
  /// server qabul qilgach tozalanadi.
  Future<void> _reportUninstallGuard() async {
    const guard = UninstallProtectionService();
    if (!await guard.hasDeactivatedFlag()) return;
    if (await _policyRepo.reportUninstallGuardDisabled(childId)) {
      await guard.clearDeactivatedFlag();
    }
  }

  void _subscribeConnectivity() {
    final stream = _connectivity ?? _defaultConnectivity();
    if (stream == null) return;
    _connectivitySub = stream.listen((isOnline) {
      final wasOnline = _wasOnline;
      _wasOnline = isOnline;
      // Faqat "yo'q → bor" o'tishida (birinchi hodisa holatni bildiradi).
      if (!isOnline || wasOnline != false) return;
      _connectivityTimer?.cancel();
      _connectivityTimer = Timer(_connectivityDebounce, () {
        _connectivityTimer = null;
        unawaited(onConnectivityRestored());
      });
    }, onError: (Object e) => debugPrint('[BackgroundJobs] connectivity: $e'));
  }

  static Stream<bool>? _defaultConnectivity() {
    try {
      return Connectivity().onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
    } catch (e) {
      debugPrint('[BackgroundJobs] connectivity yo\'q: $e');
      return null;
    }
  }

  Future<void> _runAll(List<_Job> jobs) =>
      Future.wait([for (final job in jobs) _guard(job.name, job.run)]);

  void _fire(
    String name,
    Future<void> Function() job, {
    Duration timeout = _jobTimeout,
  }) => unawaited(_guard(name, job, timeout: timeout));

  /// Bitta ish: xato va osilish boshqalariga ta'sir qilmaydi.
  Future<void> _guard(
    String name,
    Future<void> Function() job, {
    Duration timeout = _jobTimeout,
  }) async {
    if (_isStopped) return;
    try {
      await job().timeout(timeout);
    } on TimeoutException {
      debugPrint('[BackgroundJobs] $name: vaqt tugadi');
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'jobs.$name');
    }
  }
}
