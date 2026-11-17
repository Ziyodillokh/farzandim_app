// ─────────────────────────────────────────────────────────────────────
// RestrictionsSyncService — ota-ona cheklovlari → native RestrictionService
// ─────────────────────────────────────────────────────────────────────
//
// Backend manbalari (jadval oynalari, ilova limitlari, jadvallar/School Mode,
// qurilma siyosati, faol qo'shimcha vaqt) bitta REJAga yig'iladi, keshlanadi
// va hozirgi vaqtga qo'llanib prefs'ga yoziladi (RestrictionSnapshot).
//
// Doimiy so'rov (poll) YO'Q. Trigger'lar:
//   - start()            — darhol keshdagi reja + tarmoqdan olish;
//   - sync()             — WS/FCM push (2 s ichidagi turtkilar bittaga);
//   - onTick()           — 5 daqiqalik alarm: reja ≥ 4.5 daq eski bo'lsa
//                          tarmoqdan, aks holda faqat mahalliy qayta qo'llash;
//   - onScreenOn()       — darhol qayta qo'llash + reja ≥ 2 daq eski bo'lsa
//                          tarmoqdan;
//   - onConnectivityRestored() — internet qaytdi;
//   - chegara taymeri    — keyingi oyna boshlanishi/tugashi, grant tugashi,
//                          maktabdan chiqish kutish muddati (bir martalik);
//   - yangi joylashuv    — hudud oynasi faol bo'lsa qaror qayta hisoblanadi.
// Tarmoq so'rovi bir vaqtda bittadan; xatoda eksponensial kutish (≤ 5 daq).
//
// FAIL-CLOSED: tarmoq bo'lmasa oxirgi reja qayta qo'llanadi; reja hech
// olinmagan bo'lsa prefs'ga tegilmaydi. Unpair'dan keyin (prefs `childId`
// boshqa/yo'q) hech narsa yozilmaydi.
//
// Faqat Android: prefs'ni native RestrictionService o'qiydi. iOS'da —
// IosRestrictionsSyncService (provider tanlaydi).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan_fetcher.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_snapshot.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart';
import 'package:farzandim_child/features/background/data/services/background_telemetry.dart';
import 'package:farzandim_child/features/background/data/services/job_timing.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

class RestrictionsSyncService implements RestrictionsSync {
  RestrictionsSyncService({
    required BackendScheduleRepository scheduleRepo,
    required BackendAppLimitRepository appLimitRepo,
    required BackendRoutineRepository routineRepo,
    required BackendDevicePolicyRepository devicePolicyRepo,
    BackendUnlockRequestRepository? unlockRepo,
    DateTime Function()? clock,
    int Function()? clockOffsetMs,
    Future<void> Function()? ensureClockLoaded,
    Stream<int>? clockOffsetChanges,
    DateTime Function()? deviceClock,
    Future<SharedPreferences> Function()? prefs,
    Future<bool> Function()? locationOn,
    Duration debounce = const Duration(seconds: 2),
  }) : _fetcher = RestrictionPlanFetcher(
         scheduleRepo: scheduleRepo,
         appLimitRepo: appLimitRepo,
         routineRepo: routineRepo,
         devicePolicyRepo: devicePolicyRepo,
         unlockRepo: unlockRepo,
       ),
       _clock = clock ?? TrustedClock.now,
       _clockOffsetMs = clockOffsetMs ?? (() => TrustedClock.offsetMs),
       _ensureClockLoaded = ensureClockLoaded ?? TrustedClock.ensureLoaded,
       _clockOffsetChanges = clockOffsetChanges,
       _deviceClock = deviceClock ?? DateTime.now,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _locationOn = locationOn ?? _defaultLocationOn,
       _debounce = debounce;

  /// Tick'da tarmoqdan olish shundan eski reja uchun.
  static const tickFetchInterval = Duration(minutes: 4, seconds: 30);

  /// Ekran yoqilganda / internet qaytganda tarmoqdan olish chegarasi.
  static const screenOnFetchInterval = Duration(minutes: 2);

  static const _fetchTimeout = Duration(seconds: 45);
  static const _fetchedAtWriteInterval = Duration(minutes: 10);
  static const _zoneFixDelay = Duration(seconds: 2);
  static const _timerGrace = Duration(milliseconds: 500);

  final RestrictionPlanFetcher _fetcher;

  /// Ishonchli vaqt (oynalar, epoch qiymatlar).
  final DateTime Function() _clock;
  final int Function() _clockOffsetMs;

  /// Saqlangan soat siljishini o'qish (aks holda 0 bilan native'ga noto'g'ri
  /// siljish yozilardi).
  final Future<void> Function() _ensureClockLoaded;

  /// Siljish 30 s dan ko'p o'zgardi — reja qayta qo'llanadi.
  final Stream<int>? _clockOffsetChanges;

  /// Qurilma soati (joylashuv nuqtasi va "muddati keldimi" bilan bir asos).
  final DateTime Function() _deviceClock;
  final Future<SharedPreferences> Function() _prefs;
  final Future<bool> Function() _locationOn;
  final Duration _debounce;

  final Backoff _backoff = Backoff(
    first: const Duration(seconds: 30),
    max: const Duration(minutes: 5),
  );

  String? _childId;
  bool _isDisposed = false;
  bool _isListeningZone = false;
  StreamSubscription<int>? _offsetSub;
  Future<void>? _fetching;
  bool _isRerunRequested = false;
  Timer? _debounceTimer;
  Completer<void>? _debounced;
  DateTime? _lastFetchOk;
  int? _fetchedAtWrittenMs;
  Timer? _boundaryTimer;
  Timer? _zoneFixTimer;
  bool _isZoneWindowActive = false;
  String? _cachedPlanRaw;
  RestrictionPlan? _cachedPlan;
  Future<void> _applyChain = Future<void>.value();

  /// Pairing (yoki fon servisi) boshida: keshdagi reja darhol, so'ng tarmoq.
  /// Davriy taymer YO'Q — qarang sarlavha.
  @override
  void start({required String childId}) {
    _childId = childId;
    _isDisposed = false;
    if (!_isListeningZone) {
      SchoolZoneStore.addFixListener(_onZoneFix);
      _isListeningZone = true;
    }
    _offsetSub ??= (_clockOffsetChanges ?? TrustedClock.offsetChanges).listen(
      (_) => unawaited(reapply()),
    );
    debugPrint('RestrictionsSync: start $childId');
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await reapply();
    await syncNow();
  }

  /// WS/FCM push: 2 s ichida kelgan turtkilar bitta so'rovga yig'iladi.
  @override
  Future<void> sync() {
    if (_childId == null || _isDisposed) return Future<void>.value();
    final pending = _debounced;
    if (pending != null) return pending.future;
    final completer = Completer<void>();
    _debounced = completer;
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      _debounced = null;
      syncNow(rerunIfBusy: true).whenComplete(() {
        if (!completer.isCompleted) completer.complete();
      });
    });
    return completer.future;
  }

  /// Darhol tarmoqdan olish + qo'llash. Bir vaqtda faqat bitta so'rov;
  /// [rerunIfBusy] — so'rov paytida kelgan push: tugagach yana bir marta
  /// (eski javob yangi o'zgarish ustidan qolmasin).
  Future<void> syncNow({bool rerunIfBusy = false}) {
    if (_childId == null || _isDisposed) return Future<void>.value();
    final running = _fetching;
    if (running != null) {
      if (rerunIfBusy) _isRerunRequested = true;
      return running;
    }
    final run = _fetchLoop().whenComplete(() => _fetching = null);
    _fetching = run;
    return run;
  }

  /// Faqat mahalliy: keshdagi rejani hozirgi vaqtga qayta qo'llash.
  Future<void> reapply() => _serialized(() async {
    final prefs = await _prefs();
    // Boshqa isolate yozgan reja/nuqtani ko'rish uchun SHART.
    await prefs.reload();
    final plan = _readCachedPlan(prefs);
    if (plan == null) return;
    await _applyPlan(prefs, plan);
  });

  /// Ekran yoqildi: darhol qayta qo'llash; reja ≥ 2 daq eski bo'lsa tarmoqdan.
  Future<void> onScreenOn() async {
    await reapply();
    if (_isFetchDue(screenOnFetchInterval)) await syncNow();
  }

  /// 5 daqiqalik tick.
  Future<void> onTick() async {
    if (_isFetchDue(tickFetchInterval)) {
      await syncNow();
    } else {
      await reapply();
    }
  }

  /// Internet qaytdi: kutish bekor, reja eski bo'lsa darhol olinadi.
  Future<void> onConnectivityRestored() async {
    _backoff.reset();
    if (_isFetchDue(screenOnFetchInterval)) await syncNow();
  }

  /// Unpair: barcha cheklov holatini o'chiradi (restriction.*, school_zone.*,
  /// game.pending, limit_warned). Til matnlari (restriction.i18n.*) qoladi.
  static Future<void> clearEnforcementState(SharedPreferences prefs) =>
      clearRestrictionState(prefs);

  /// Ota-onaning "O'chirishni taqiqlash" qiymati (UI resume'da qo'llaydi);
  /// `null` — hali olinmagan.
  static bool? readBlockUninstall(SharedPreferences prefs) {
    final value = prefs.get(RestrictionKeys.blockUninstall);
    return value is bool ? value : null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final pending = _debounced;
    _debounced = null;
    if (pending != null && !pending.isCompleted) pending.complete();
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
    _zoneFixTimer?.cancel();
    _zoneFixTimer = null;
    if (_isListeningZone) {
      SchoolZoneStore.removeFixListener(_onZoneFix);
      _isListeningZone = false;
    }
    unawaited(_offsetSub?.cancel());
    _offsetSub = null;
  }

  // ─── Tarmoq ─────────────────────────────────────────────────────────

  bool _isFetchDue(Duration interval) {
    if (_childId == null || _isDisposed) return false;
    final now = _deviceClock();
    if (_backoff.isBlocked(now)) return false;
    return isDue(_lastFetchOk, now, interval);
  }

  Future<void> _fetchLoop() async {
    do {
      _isRerunRequested = false;
      await _fetchAndApply();
    } while (_isRerunRequested && !_isDisposed);
  }

  Future<void> _fetchAndApply() async {
    final childId = _childId;
    if (childId == null || _isDisposed) return;
    final startedAt = _deviceClock();
    RestrictionPlan? fetched;
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final legacyBlockAll = prefs.get(RestrictionKeys.legacyBlockAllCache);
      fetched = await _fetcher
          .fetch(
            childId,
            cached: _readCachedPlan(prefs),
            legacyBlockAll: legacyBlockAll is bool && legacyBlockAll,
            planDay: () => tashkentDayKey(_clock()),
          )
          .timeout(_fetchTimeout);
    } on TimeoutException {
      debugPrint('RestrictionsSync: tarmoq so\'rovi vaqti tugadi');
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'restrictions.fetch');
    }
    if (_isDisposed) return;
    if (fetched == null) {
      _backoff.fail(_deviceClock());
    } else {
      _backoff.reset();
      _lastFetchOk = startedAt;
    }
    final plan = fetched;
    await _serialized(() async {
      final prefs = await _prefs();
      await prefs.reload();
      if (_isDisposed || !_isStillPaired(prefs)) return;
      if (plan != null) await _storePlan(prefs, plan);
      // FAIL-CLOSED: tarmoq bo'lmasa OXIRGI reja qayta qo'llanadi.
      final effective = plan ?? _readCachedPlan(prefs);
      if (effective == null) {
        debugPrint('RestrictionsSync: reja yo\'q — prefs o\'zgarmadi');
        return;
      }
      await _applyPlan(prefs, effective);
    });
  }

  /// Reja keshi FAQAT mazmuni o'zgarganda yoziladi; olingan vaqt — alohida
  /// kalitda, ko'pi bilan 10 daqiqada bir.
  Future<void> _storePlan(SharedPreferences prefs, RestrictionPlan plan) async {
    final raw = plan.toJsonString();
    if (prefs.get(RestrictionKeys.planCache) != raw) {
      await prefs.setString(RestrictionKeys.planCache, raw);
    }
    _cachedPlanRaw = raw;
    _cachedPlan = plan;

    final nowMs = _clock().millisecondsSinceEpoch;
    final stored = prefs.get(RestrictionKeys.planFetchedAtMs);
    final last = _fetchedAtWrittenMs ?? (stored is int ? stored : null);
    if (last == null ||
        (nowMs - last).abs() >= _fetchedAtWriteInterval.inMilliseconds) {
      await prefs.setInt(RestrictionKeys.planFetchedAtMs, nowMs);
      _fetchedAtWrittenMs = nowMs;
    }

    final blockUninstall = plan.blockUninstall;
    if (blockUninstall != null &&
        prefs.get(RestrictionKeys.blockUninstall) != blockUninstall) {
      await prefs.setBool(RestrictionKeys.blockUninstall, blockUninstall);
    }
  }

  // ─── Qo'llash ───────────────────────────────────────────────────────

  RestrictionPlan? _readCachedPlan(SharedPreferences prefs) {
    final raw = prefs.get(RestrictionKeys.planCache);
    if (raw is! String) return null;
    if (raw == _cachedPlanRaw) return _cachedPlan;
    final plan = RestrictionPlan.tryFromJson(raw);
    _cachedPlanRaw = raw;
    _cachedPlan = plan;
    return plan;
  }

  /// Unpair qilingan yoki boshqa bola ulangan bo'lsa — hech narsa yozilmaydi.
  bool _isStillPaired(SharedPreferences prefs) {
    final stored = prefs.get('childId');
    return stored is String && stored == _childId;
  }

  Future<void> _applyPlan(SharedPreferences prefs, RestrictionPlan plan) async {
    // To'xtatilgan (unpair / servis yopilmoqda) yoki boshqa bola — yozilmaydi.
    if (_isDisposed || !_isStillPaired(prefs)) return;
    await _ensureClockLoaded();
    final now = _clock();
    var insideZone = true;
    ZoneMemory? memory;
    final zone = activeSchoolZone(plan, now);
    if (zone != null) {
      final decision = decideZone(
        zone: zone,
        fix: SchoolZoneStore.readFix(prefs),
        memory: SchoolZoneStore.readMemory(prefs),
        // Nuqta vaqti qurilma soatida — taqqoslash ham shu asosda.
        now: _deviceClock(),
        locationOn: await _locationOn(),
      );
      memory = decision.memory;
      insideZone = decision.inside;
      await SchoolZoneStore.writeMemory(prefs, decision.memory);
    } else if (prefs.containsKey(SchoolZoneStore.memoryKey)) {
      // Hudud xotirasi har oyna uchun alohida: oyna tugagach tozalanadi.
      await prefs.remove(SchoolZoneStore.memoryKey);
    }
    _isZoneWindowActive = zone != null;
    if (_isDisposed) return;

    final snapshot = buildSnapshot(
      plan,
      now,
      insideZone: insideZone,
      clockOffsetMs: _clockOffsetMs(),
    );
    final written = await writeSnapshot(prefs, snapshot);
    if (written.isNotEmpty) {
      debugPrint(
        'RestrictionsSync: yozildi ${written.length} kalit, '
        'zone=${zone != null ? (insideZone ? 'ichida' : 'tashqarida') : '-'}',
      );
    }
    _armTimer(plan, snapshot, now, memory);
  }

  /// Bitta taymer: oyna chegarasi, grant tugashi yoki maktabdan chiqish
  /// kutish muddati — qaysi biri oldin bo'lsa. Devor soati bo'yicha har
  /// qo'llashda qayta hisoblanadi (uyquda Timer kechiksa — tick tuzatadi).
  void _armTimer(
    RestrictionPlan plan,
    RestrictionSnapshot snapshot,
    DateTime now,
    ZoneMemory? memory,
  ) {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
    if (_isDisposed) return;
    final nowMs = now.millisecondsSinceEpoch;
    final delays = <Duration>[
      if (snapshot.validUntilMs > 0)
        Duration(milliseconds: snapshot.validUntilMs - nowMs),
      for (final g in plan.grants)
        if (g.expiresAtMs > nowMs)
          Duration(milliseconds: g.expiresAtMs - nowMs),
    ];
    final outsideSince = memory?.outsideSince;
    if (outsideSince != null) {
      delays.add(outsideSince.add(kZoneExitDwell).difference(_deviceClock()));
    }
    if (delays.isEmpty) return;
    var delay = delays.reduce((a, b) => a < b ? a : b) + _timerGrace;
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _boundaryTimer = Timer(delay, _onBoundary);
  }

  void _onBoundary() {
    _boundaryTimer = null;
    if (_isDisposed) return;
    // Grant tugadi — serverdagi limit qo'shimchasiz qaytadi: tarmoqdan olamiz.
    final nowMs = _clock().millisecondsSinceEpoch;
    final hasEndedGrant =
        _cachedPlan?.grants.any((g) => g.expiresAtMs <= nowMs) ?? false;
    if (hasEndedGrant && !_backoff.isBlocked(_deviceClock())) {
      unawaited(syncNow());
    } else {
      unawaited(reapply());
    }
  }

  /// Yangi joylashuv nuqtasi (shu isolate) — hudud oynasi faol bo'lsa qaror
  /// darhol qayta hisoblanadi (maktabga kelganda blok kechikmasin).
  void _onZoneFix() {
    if (_isDisposed || !_isZoneWindowActive || _zoneFixTimer != null) return;
    _zoneFixTimer = Timer(_zoneFixDelay, () {
      _zoneFixTimer = null;
      unawaited(reapply());
    });
  }

  /// Prefs yozuvlari ketma-ket (tarmoq natijasi va mahalliy qayta qo'llash
  /// bir-birining ustiga yozmasin).
  Future<void> _serialized(Future<void> Function() body) {
    final run = _applyChain.then((_) => _guarded(body));
    _applyChain = run;
    return run;
  }

  static Future<void> _guarded(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'restrictions.apply');
    }
  }

  /// Joylashuv xizmati va ruxsati bormi (bilib bo'lmasa — bor deb, qaror
  /// nuqta yangiligiga tayanadi).
  static Future<bool> _defaultLocationOn() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return true;
    }
  }
}
