// ─────────────────────────────────────────────────────────────────────
// LocationService — bola joylashuvi (ota-ona xaritasi, tarix, maktab hududi)
// ─────────────────────────────────────────────────────────────────────
//
// 1.0.20 (batareya): doimiy GPS oqimi (HIGH, 5 s) va 60 s'lik GPS heartbeat
// OLIB TASHLANDI. Strategiya `location_strategy.dart`da (sof, testlanadi):
//   - statsionar: balanced (Wi-Fi/uyali, GNSS'siz) 50 m / 3 daqiqa;
//   - safar: GPS 20 m / 20 s — bola yurganda; 5 daqiqa turib qolsa tugaydi.
// Rejim almashsa oqim QAYTA obuna bo'ladi — har doim BITTA oqim.
//
// O'z davriy taymeri YO'Q. Tashqi chaqiruvlar (BackgroundJobs):
//   - start()/stop() — Android: FGS isolate; iOS: UI isolate;
//   - onTick() — ~5 daqiqa: nuqta eskirgan bo'lsa BITTA balanced fix,
//     "tirikman" nuqtasi, ruxsat/GPS keyin yoqilsa oqimni qayta ochish
//     (avvalgi 60 s'lik retry taymeri o'rniga);
//   - onWake() — `parvoz:location_wake` (ota-ona xaritani ochdi): bitta GPS
//     fix darhol yuboriladi + 2 daqiqa safar rejimi;
//   - sendWakeFix() — UI isolate / FCM fon engine uchun (static).
// Faqat safardan chiqish uchun bitta one-shot taymer (tick — zaxira).
//
// Bitta isolate'da bitta faol nusxa: keyingi start() oldingisini to'xtatadi,
// boshqa nusxaga kelgan onTick/onWake faol nusxaga uzatiladi.
//
// iOS: oqim fonda ham ishlaydi (allowBackgroundLocationUpdates, avto-pauza
// o'chiq — avvalgidek). "While in use" ruxsatida iOS fonda oqimni qayta
// ochishga yo'l qo'ymaydi — rejim almashuvi faqat ilova ochiq yoki "Har doim"
// ruxsatida; aks holda keyingi tick/ochilishgacha kutadi.
//
// Koordinatalar log'ga YOZILMAYDI (bola joylashuvi — maxfiy ma'lumot).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart';
import 'package:farzandim_child/features/location/data/services/location_platform.dart';
import 'package:farzandim_child/features/location/data/services/location_strategy.dart';
import 'package:farzandim_child/features/location/data/services/location_uploader.dart';

/// Maktab hududi nuqtasini saqlovchi (standart — [SchoolZoneStore.recordFix]).
typedef ZoneFixRecorder = Future<void> Function(LocationSample sample);

class LocationService {
  LocationService({
    LocationUploader? uploader,
    ZoneFixRecorder? recordZoneFix,
    DateTime Function()? clock,
  }) : _uploaderOverride = uploader,
       _recordZoneFix = recordZoneFix ?? _recordToSchoolZone,
       _clock = clock ?? DateTime.now;

  /// Shu isolate'dagi faol nusxa (oqim egasi).
  static LocationService? _owner;

  /// sendWakeFix uchun start qilinmagan (oqimsiz) nusxa — har push'da yangi
  /// Dio/OfflineBuffer yaratilmasin.
  static LocationService? _wakeOnly;

  final LocationUploader? _uploaderOverride;
  late final LocationUploader _uploader =
      _uploaderOverride ?? BackendLocationUploader();
  final ZoneFixRecorder _recordZoneFix;
  final DateTime Function() _clock;

  String? _parentUid;
  String? _childId;
  bool _active = false;
  LocationTracker _tracker = const LocationTracker();

  StreamSubscription<Position>? _sub;
  LocationMode? _subMode;
  int _gen = 0; // obuna avlodi — eski oqim callback'lari e'tiborsiz
  Future<void> _streamOps = Future<void>.value(); // oqim amallari ketma-ket

  Timer? _tripExitTimer;
  DateTime? _tripExitAt;

  Future<void>? _fixing;
  Future<void>? _ticking;
  Future<void>? _waking;
  DateTime? _lastWakeAt;

  /// Hozir obuna bo'lingan rejim (oqim yo'q — null).
  @visibleForTesting
  LocationMode? get streamMode => _subMode;

  @visibleForTesting
  LocationTracker get tracker => _tracker;

  /// Oqimni boshlaydi. Idempotent: shu juftlik bilan oqim ishlayotgan bo'lsa
  /// hech narsa qilmaydi. Ruxsat/GPS yo'q bo'lsa jim qaytadi — [onTick]
  /// qayta urinadi.
  Future<void> start({
    required String parentUid,
    required String childId,
    required String childName,
  }) async {
    if (kIsWeb) return;
    _claimIsolate();
    final same = _active && parentUid == _parentUid && childId == _childId;
    _active = true;
    if (same && _sub != null) return;
    if (!same) {
      _parentUid = parentUid;
      _childId = childId;
      _tracker = const LocationTracker();
      _cancelTripExit();
      await _dropStream();
    }
    if (await _ensureStream()) unawaited(_refreshFix());
  }

  /// Hammasini to'xtatadi: oqim, taymer, holat.
  void stop() {
    _active = false;
    _gen++;
    final sub = _sub;
    _sub = null;
    _subMode = null;
    if (sub != null) unawaited(sub.cancel());
    _cancelTripExit();
    _tracker = const LocationTracker();
    _parentUid = null;
    _childId = null;
    if (identical(_owner, this)) _owner = null;
  }

  /// ~5 daqiqalik tick (BackgroundJobs). Davomiyligi ≤ ~20 s (bitta fix);
  /// hudud qaroridan oldin `await` qilinsa nuqta yangi bo'ladi. Bir vaqtda
  /// ikki chaqiruv — bitta ish (ikkinchisi o'shani kutadi).
  Future<void> onTick() {
    final owner = _owner;
    if (owner != null && !identical(owner, this)) return owner.onTick();
    if (kIsWeb || !_active) return Future<void>.value();
    return _ticking ??= _tick().whenComplete(() => _ticking = null);
  }

  /// `parvoz:location_wake` — ota-ona xaritani ochdi: bitta GPS fix (aniqlik
  /// darvozasi bilan) darhol yuboriladi va 2 daqiqa safar rejimi.
  Future<void> onWake() {
    final owner = _owner;
    if (owner != null && !identical(owner, this)) return owner.onWake();
    if (kIsWeb) return Future<void>.value();
    return _waking ??= _wake().whenComplete(() => _waking = null);
  }

  /// FCM 'location_wake' (UI isolate yoki FCM fon engine). Fon servisi
  /// ishlayotgan bo'lsa — unga uzatiladi (joylashuv egasi bitta); aks holda
  /// shu yerda bitta GPS fix. Oqim ochmaydi. Hech qachon throw qilmaydi.
  static Future<void> sendWakeFix() async {
    if (kIsWeb) return;
    final owner = _owner;
    if (owner != null) return owner.onWake();
    if (await LocationPlatform.forwardWakeToForegroundTask()) return;
    return (_wakeOnly ??= LocationService()).onWake();
  }

  @visibleForTesting
  static void debugResetIsolate() {
    _owner?.stop();
    _owner = null;
    _wakeOnly = null;
  }

  // ─── Tick va wake ──────────────────────────────────────────────────

  Future<void> _tick() async {
    try {
      final usable = await _ensureStream();
      final step = _tracker.onTick(_clock());
      _applyTracker(step.tracker);
      final alive = step.alive;
      final childId = _childId;
      if (alive != null && childId != null) {
        debugPrint(
          'LocationService: tirikman nuqtasi (${alive.describe(_clock())})',
        );
        await _upload(childId, alive);
      }
      if (usable && step.requestFix) await _refreshFix();
      if (usable) await _syncStreamMode(); // iOS: kechiktirilgan almashuv
    } catch (e) {
      debugPrint('LocationService: tick xato: $e');
    }
  }

  Future<void> _wake() async {
    try {
      final now = _clock();
      final last = _lastWakeAt;
      if (last != null &&
          now.difference(last).abs() < LocationTuning.wakeCooldown) {
        return;
      }
      _lastWakeAt = now;
      // Start qilinmagan nusxa (FCM fon engine): juftlik HAR SAFAR prefs'dan
      // — re-pair/unpair'dan keyin eski id bilan yuborilmasin.
      if (!_active) await _loadPairing();
      final childId = _childId;
      if (childId == null || _parentUid == null) return;
      if (!await LocationPlatform.isUsable()) return;
      if (_active) _applyTracker(_tracker.holdTrip(now));
      final fix = await LocationPlatform.oneShot(
        LocationAccuracy.high,
        LocationTuning.wakeFixTimeLimit,
      );
      if (fix == null || _childId != childId) return;
      await _handleSample(fix, force: true);
    } catch (e) {
      debugPrint('LocationService: wake fix yuborilmadi: $e');
    }
  }

  /// Nuqta eskirgan: avval OS keshi (bepul), bo'lmasa BITTA balanced fix.
  Future<void> _refreshFix() =>
      _fixing ??= _doRefreshFix().whenComplete(() => _fixing = null);

  Future<void> _doRefreshFix() async {
    try {
      final known = await LocationPlatform.lastKnown();
      if (known != null && _tracker.isFreshCandidate(known, _clock())) {
        await _handleSample(known);
        return;
      }
      final fix = await LocationPlatform.oneShot(
        LocationAccuracy.medium,
        LocationTuning.tickFixTimeLimit,
      );
      if (fix != null) await _handleSample(fix);
    } catch (e) {
      debugPrint('LocationService: yangi fix olinmadi: $e');
    }
  }

  // ─── Oqim ──────────────────────────────────────────────────────────

  void _claimIsolate() {
    final owner = _owner;
    if (owner != null && !identical(owner, this)) {
      debugPrint(
        "LocationService: oldingi nusxa to'xtatildi (isolate'da bitta oqim)",
      );
      owner.stop();
    }
    _owner = this;
  }

  /// Oqim amallari (obuna, qayta obuna, yopish) ketma-ket — ikki oqim
  /// hech qachon bir vaqtda ochilmaydi.
  Future<T> _serial<T>(Future<T> Function() op, T fallback) {
    final next = _streamOps.then((_) => op()).catchError((Object e) {
      debugPrint('LocationService: oqim amali xato: $e');
      return fallback;
    });
    _streamOps = next.then((_) {});
    return next;
  }

  /// Oqim ishlayaptimi; yo'q bo'lsa ruxsat/GPS'ni tekshirib ochadi.
  Future<bool> _ensureStream() => _serial<bool>(() async {
    if (!_active) return false;
    if (_sub != null) return true;
    if (!await LocationPlatform.isUsable(logState: true)) return false;
    await _subscribe(_tracker.mode);
    return _sub != null;
  }, false);

  /// Holatdagi rejim oqimdagidan farq qilsa — qayta obuna.
  Future<void> _syncStreamMode() => _serial<void>(() async {
    final want = _tracker.mode;
    if (!_active || _sub == null || _subMode == want) return;
    if (!await LocationPlatform.canSwitchStreamNow()) {
      debugPrint('LocationService: iOS fonda — rejim almashuvi keyinroq');
      return;
    }
    await _subscribe(want);
  }, null);

  Future<void> _dropStream() => _serial<void>(() async {
    _gen++;
    final old = _sub;
    _sub = null;
    _subMode = null;
    await old?.cancel();
  }, null);

  /// Faqat [_serial] ichidan. Avval eski oqim YOPILADI: geolocator oqimni
  /// oxirgi tinglovchi chiqmaguncha keshlaydi — yopmasdan so'ralsa yangi
  /// sozlama emas, ESKI oqim qaytadi.
  Future<void> _subscribe(LocationMode mode) async {
    final gen = ++_gen;
    final old = _sub;
    _sub = null;
    _subMode = null;
    if (old != null) {
      await old.cancel();
      await Future<void>.delayed(Duration.zero);
    }
    if (gen != _gen || !_active) return;
    _subMode = mode;
    _sub = LocationPlatform.positions(mode).listen(
      (p) {
        if (gen == _gen) unawaited(_handleSample(LocationPlatform.sampleOf(p)));
      },
      onError: (Object e) {
        if (gen == _gen) _onStreamError(e);
      },
      onDone: () {
        if (gen != _gen) return;
        _sub = null;
        _subMode = null;
      },
    );
    debugPrint('LocationService: oqim — ${mode.name}');
  }

  void _onStreamError(Object error) {
    debugPrint('LocationService: oqim xato: $error');
    if (error is PermissionDeniedException ||
        error is LocationServiceDisabledException) {
      // Oqim foydasiz — keyingi tick ruxsat/GPS'ni tekshirib qayta ochadi.
      unawaited(_dropStream());
    }
  }

  // ─── Nuqtalar ──────────────────────────────────────────────────────

  Future<void> _handleSample(
    LocationSample sample, {
    bool force = false,
  }) async {
    final childId = _childId;
    if (childId == null) return;
    final outcome = _tracker.onSample(sample, now: _clock(), force: force);
    _applyTracker(outcome.tracker);
    if (outcome.recordZone) await _recordZone(sample);
    if (outcome.send) {
      await _upload(childId, sample);
    } else if (force) {
      debugPrint(
        'LocationService: wake fix yuborilmadi (${sample.describe(_clock())})',
      );
    }
  }

  void _applyTracker(LocationTracker next) {
    final from = _tracker.mode;
    _tracker = next;
    if (from != next.mode) {
      debugPrint('LocationService: rejim ${from.name} → ${next.mode.name}');
    }
    _scheduleTripExit();
    if (_active && _subMode != next.mode) unawaited(_syncStreamMode());
  }

  // ─── Safardan chiqish taymeri (yagona one-shot) ──────────────────────

  void _scheduleTripExit() {
    final exitAt = _tracker.motion.exitAt;
    if (exitAt == null || !_active) {
      _cancelTripExit();
      return;
    }
    if (_tripExitTimer != null && _tripExitAt == exitAt) return;
    _tripExitTimer?.cancel();
    _tripExitAt = exitAt;
    final delay = exitAt.difference(_clock());
    _tripExitTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _tripExitTimer = null;
      _tripExitAt = null;
      if (_active) _applyTracker(_tracker.onClock(_clock()));
    });
  }

  void _cancelTripExit() {
    _tripExitTimer?.cancel();
    _tripExitTimer = null;
    _tripExitAt = null;
  }

  // ─── Yordamchilar ──────────────────────────────────────────────────

  Future<void> _loadPairing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Boshqa isolate yozgan bo'lishi mumkin (re-pair/unpair).
      await prefs.reload();
      _parentUid = prefs.getString('parentUid');
      _childId = prefs.getString('childId');
    } catch (e) {
      debugPrint("LocationService: juftlik o'qilmadi: $e");
    }
  }

  Future<void> _upload(String childId, LocationSample sample) async {
    try {
      await _uploader.post(childId: childId, sample: sample);
    } catch (e) {
      debugPrint('LocationService: yuborilmadi (${e.runtimeType})');
    }
  }

  Future<void> _recordZone(LocationSample sample) async {
    try {
      await _recordZoneFix(sample);
    } catch (e) {
      debugPrint('LocationService: hudud nuqtasi yozilmadi (${e.runtimeType})');
    }
  }

  static Future<void> _recordToSchoolZone(LocationSample s) =>
      SchoolZoneStore.recordFix(
        latitude: s.latitude,
        longitude: s.longitude,
        accuracyM: s.accuracyM,
        at: s.at,
      );
}
