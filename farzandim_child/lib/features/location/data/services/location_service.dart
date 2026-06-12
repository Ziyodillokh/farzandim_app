// ─────────────────────────────────────────────────────────────────────
// LocationService — bola joylashuvini real-vaqtda Firestore'ga yozuvchi
// ─────────────────────────────────────────────────────────────────────
//
// Pairing tugagach `start()` chaqiriladi. Geolocator position stream
// `distanceFilter: 10m` bilan obuna bo'ladi — bola 10 metr siljiganda
// yangi koordinata Firestore'ga yoziladi (`location` field). App ochiq
// paytda ishlaydi (foreground); to'liq background 8.F'da Foreground
// Service bilan qo'shiladi.
//
// Permission gating:
//   - Permission.locationWhenInUse `granted` bo'lmasa start() jim
//     qaytib ketadi (PermissionsScreen foydalanuvchidan ruxsat oladi).
//
// `getCurrentPosition()` chaqirilmaydi — u GPS fix kelguncha cheksiz
// kutadi va `await` ni bloklaydi (xona ichida UX hang). `getPositionStream`
// o'z-o'zidan birinchi pozitsiyani emit qiladi (cached last known yoki
// yangi fix), shuning uchun bitta source of truth — non-blocking.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';

class LocationService {
  // ─── Backend Dio (Sprint 4.4) ─────────────────────────────────────
  // Auth + REFRESH interceptorli (createBackendDio). 15-daqiqalik access
  // token tugaganda avtomatik yangilanadi — shu sababli background
  // isolate'da ham (app yopiq) joylashuv/device-info to'xtab qolmaydi.
  late final Dio _dio = _buildDio();
  final TokenStorage _tokenStorage = TokenStorage();
  final OfflineBuffer _offlineBuffer = OfflineBuffer();

  Dio _buildDio() => createBackendDio(_tokenStorage);

  // Firestore field olib tashlandi — Backend POST /location ishlatamiz.

  /// Heartbeat oralig'i — har 60s lokatsiya holati tekshiriladi. Stream
  /// jonli bo'lsa oxirgi nuqta yuboriladi, eskirgan bo'lsa yangi fix
  /// so'raladi (_heartbeatTick). Backend stop-detection (≥2.5 daqiqa)
  /// shu sample'larga tayanadi; <10m dedup bloat'ni oldini oladi.
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  // Ruxsat/GPS yo'qligida start()ni davriy qayta urinish (60s) — bola GPS'ni
  // keyin yoqsa joylashuv o'z-o'zidan tiklanadi (servis restart kutmaydi).
  Timer? _startRetryTimer;
  Position? _lastPosition;
  String? _parentUid;
  String? _childId;

  // Sprint 4.4.23 fix: device info Backend'ga yuboriladi
  // (DeviceInfoService Firestore writes o'rniga).
  String? _cachedDeviceModel;
  String? _cachedAndroidVersion;
  String? _cachedAppVersion;
  DateTime? _lastWifiCheck;
  String? _cachedWifiName;

  Future<void> _ensureDeviceInfo() async {
    if (_cachedDeviceModel != null) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cachedDeviceModel = '${info.brand} ${info.model}';
      _cachedAndroidVersion = 'Android ${info.version.release}';
    } catch (_) {
      // iOS yoki plugin xato — skip
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      _cachedAppVersion = pkg.version;
    } catch (_) {
      // skip
    }
  }

  Future<String?> _getWifiName() async {
    // Wi-Fi nomi har 5 daqiqada bir marta o'qiladi (battery + permission cost).
    final now = DateTime.now();
    if (_lastWifiCheck != null &&
        now.difference(_lastWifiCheck!).inMinutes < 5) {
      return _cachedWifiName;
    }
    _lastWifiCheck = now;
    try {
      final ssid = await NetworkInfo().getWifiName();
      if (ssid == null || ssid.isEmpty) {
        _cachedWifiName = null;
        return null;
      }
      final cleaned = ssid.replaceAll('"', '').trim();
      if (cleaned == '<unknown ssid>' || cleaned.isEmpty) {
        _cachedWifiName = null;
        return null;
      }
      _cachedWifiName = cleaned;
      return cleaned;
    } catch (_) {
      _cachedWifiName = null;
      return null;
    }
  }

  /// Position stream'ga obuna bo'ladi va har 10m harakatda Firestore'ga
  /// yangi joylashuvni yozadi. Permission yo'q bo'lsa jim chiqadi.
  Future<void> start({
    required String parentUid,
    required String childId,
    required String childName,
  }) async {
    _parentUid = parentUid;
    _childId = childId;

    // Web'da background location va permission_handler API yo'q —
    // jim chiqamiz, real Android/iOS qurilmalarda ishlatiladi.
    if (kIsWeb) return;

    // 1. Permission tekshirish. MUHIM: ruxsat yo'q bo'lsa JIM O'LIB QOLMAYMIZ
    // — retry timer qo'yamiz. Boot'dan start bo'lganda GPS hali o'chiq
    // bo'lishi yoki bola GPS'ni keyin yoqishi tabiiy; avval bu yerda quruq
    // `return` edi → joylashuv servis restart'igacha umuman o'lik qolardi
    // (bola "online" ko'rinib joylashuvi soatlab eskirardi).
    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      debugPrint(
          'LocationService: ruxsat yo\'q ($status) — 60s\'da qayta urinamiz');
      _scheduleStartRetry();
      return;
    }

    // 2. Service yoqilganligini tekshirish (GPS o'chiq bo'lishi mumkin)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: GPS o\'chiq — 60s\'da qayta urinamiz');
      _scheduleStartRetry();
      return;
    }

    // Diagnostika: Android 11+ background fix uchun locationAlways kerak.
    // While-in-use bilan foreground-service location type bor — ishlaydi,
    // lekin OEM cheklovlarida fix kelmasligi mumkin; log foydali signal.
    final always = await Permission.locationAlways.isGranted;
    if (!always) {
      debugPrint(
        "LocationService: faqat while-in-use ruxsat — background fix "
        'kelmasligi mumkin (Android 11+)',
      );
    }

    // Muvaffaqiyatli start — retry endi kerak emas.
    _startRetryTimer?.cancel();
    _startRetryTimer = null;

    // 2b. Geo zone watcher Sprint 4.4'da olib tashlandi — Backend
    // POST /location'da geofence avtomatik aniqlanadi va parent'ga
    // FCM push yuboradi. Lokal watcher'ga zarurat yo'q.

    // 3. Cached pozitsiya bo'lsa darhol yoz (sync, fast).
    // `getLastKnownPosition()` OS keshidan oxirgi ma'lum joylashuvni
    // qaytaradi — fix talab qilmaydi, shuning uchun osilmaydi.
    // Faqat 10 daqiqadan yangi bo'lsa yuboramiz — soatlab eski kesh
    // nuqta xaritada "hozirgi joy" bo'lib ko'rinib qolmasin.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().toUtc().difference(lastKnown.timestamp.toUtc()) <=
              const Duration(minutes: 10)) {
        await _writeToFirestore(lastKnown);
      }
    } catch (e) {
      debugPrint('LocationService getLastKnownPosition error: $e');
    }

    // 4. Stream'ga obuna — har 10m harakatda yangi pozitsiya.
    // Android'da vaqt-asosli interval (5s) ham beriladi — mashinada tez
    // yurganda nuqtalar siyraklashib qolmaydi.
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _streamSettings(),
    ).listen(
      _writeToFirestore,
      onError: (Object e) {
        debugPrint('LocationService stream xato: $e');
      },
    );

    // 5. Birinchi yangi GPS fix'ni majburiy so'rash (statsionar qurilma
    // muammosi). `getLastKnownPosition()` null qaytarsa va distanceFilter:
    // 10 stream emit qilmasa (harakat yo'q) — Firestore'da hech qachon
    // location ko'rinmaydi. Bu yerda 30s timeout bilan fresh fix
    // so'raymiz, lekin asinx — UI/start() ni bloklamasligi uchun.
    unawaited(_forceFirstFix());

    // 6. Heartbeat timer — har 60s lokatsiya holatini tekshiradi
    // (bola statsionar bo'lsa ham tarix bo'sh qolmasin). Mantiq
    // _heartbeatTick'da; xato heartbeat'ni yiqitmasin.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        await _heartbeatTick();
      } catch (e) {
        debugPrint('LocationService: heartbeat xato: $e');
      }
    });
  }

  /// Platformaga mos stream sozlamasi — Android'da intervalDuration bor.
  LocationSettings _streamSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  /// Heartbeat mantiq — eski nuqtani "yangi" deb qayta yubormaslik:
  /// - nuqta yoshi < 45s → stream jonli, o'shani yuboramiz;
  /// - aks holda yangi fix so'raymiz (20s limit), kelsa o'shani yuboramiz;
  /// - fix kelmasa va nuqta < 5 daqiqa → eskisini o'z vaqti bilan yuboramiz;
  /// - undan eski bo'lsa lokatsiya yuborilmaydi (batareya/holat
  ///   device-info heartbeat'da baribir ketadi).
  Future<void> _heartbeatTick() async {
    final last = _lastPosition;
    final lastAge = last == null
        ? null
        : DateTime.now().toUtc().difference(last.timestamp.toUtc());

    if (last != null && lastAge! < const Duration(seconds: 45)) {
      await _writeToFirestore(last);
      return;
    }

    try {
      final fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      // _writeToFirestore _lastPosition'ni ham yangilaydi.
      await _writeToFirestore(fresh);
      return;
    } catch (e) {
      debugPrint('LocationService: heartbeat yangi fix olinmadi: $e');
    }

    if (last != null && lastAge! < const Duration(minutes: 5)) {
      // capturedAt nuqtaning o'z vaqti bo'ladi (_postToBackend) —
      // backend'da eski nuqta yangi vaqt bilan ko'rinmaydi.
      await _writeToFirestore(last);
    }
  }

  Future<void> _forceFirstFix() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
      await _writeToFirestore(position);
    } catch (e) {
      debugPrint('LocationService getCurrentPosition first-fix error: $e');
    }
  }

  /// Ruxsat/GPS yo'qligida start()ni 60s'dan keyin qayta urinish.
  /// start() muvaffaqiyatli o'tsa timer o'zi bekor qilinadi.
  void _scheduleStartRetry() {
    _startRetryTimer?.cancel();
    _startRetryTimer = Timer(const Duration(seconds: 60), () {
      final p = _parentUid;
      final c = _childId;
      if (p == null || c == null) return;
      unawaited(start(parentUid: p, childId: c, childName: ''));
    });
  }

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _startRetryTimer?.cancel();
    _startRetryTimer = null;
    _lastPosition = null;
  }

  Future<void> _writeToFirestore(Position position) async {
    if (_parentUid == null || _childId == null) return;

    // Oxirgi pozitsiyani saqlash — heartbeat tick'da qayta yozish uchun.
    _lastPosition = position;

    // Sprint 4.4: Backend POST /api/location ishlatamiz (JWT auth).
    // Backend Postgres'ga yozadi, geofence check qiladi, parent push.
    // Eski Firestore yo'l olib tashlandi — fairlanesh ishlamaydi
    // (child Backend'da pair'lashgan, Firestore'da yo'q).
    await _postToBackend(position);
  }

  /// Backend POST /api/location — JWT auth (TokenStorage'dan).
  ///
  /// Backend response: { ok, written, location, geofenceEvents }.
  /// `geofenceEvents` — entry/exit hodisalari, Backend'da geofence
  /// avtomatik aniqlanadi. Parent App push qabul qiladi.
  Future<void> _postToBackend(Position position) async {
    try {
      // Sprint 4.4.12: battery/isCharging Backend POST /location ichida
      // yuboriladi — Backend bola obyektini avtomatik yangilaydi
      // (DeviceInfoService Firestore writes o'rniga).
      int? batteryLevel;
      bool? isCharging;
      try {
        batteryLevel = await Battery().batteryLevel;
        final batteryState = await Battery().batteryState;
        isCharging = batteryState == BatteryState.charging ||
            batteryState == BatteryState.full;
      } catch (_) {
        // Battery permission yo'q yoki plugin xato — skip
      }

      // Sprint 4.4.23: device info Backend'ga yuborish.
      await _ensureDeviceInfo();
      final wifiName = await _getWifiName();

      final payload = <String, dynamic>{
        'childId': _childId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'altitude': position.altitude,
        // Nuqtaning O'Z vaqti (GPS fix vaqti) — heartbeat qayta yuborsa
        // ham, offline flush bo'lsa ham backend to'g'ri vaqtni oladi.
        'capturedAt': position.timestamp.toUtc().toIso8601String(),
        if (batteryLevel != null) 'batteryLevel': batteryLevel,
        if (isCharging != null) 'isCharging': isCharging,
        if (_cachedDeviceModel != null) 'deviceModel': _cachedDeviceModel,
        if (_cachedAndroidVersion != null)
          'androidVersion': _cachedAndroidVersion,
        if (_cachedAppVersion != null) 'appVersion': _cachedAppVersion,
        if (wifiName != null) 'wifiName': wifiName,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/location',
        data: payload,
      );

      debugPrint(
        'LocationService: location yozildi (Backend) '
        '(${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)})',
      );

      final geofenceEvents = response.data?['geofenceEvents'];
      if (geofenceEvents is List && geofenceEvents.isNotEmpty) {
        debugPrint('LocationService: geofence events: $geofenceEvents');
      }
    } on DioException catch (e) {
      // Tarmoq xato yoki 5xx — offline buffer'ga qo'shamiz.
      // 4xx (validation) — buffer'da foyda yo'q, faqat log.
      final code = e.response?.statusCode ?? 0;
      if (code == 0 || code >= 500) {
        await _offlineBuffer.enqueue(
          endpoint: '/location',
          body: <String, dynamic>{
            'childId': _childId,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'speed': position.speed,
            'heading': position.heading,
            'altitude': position.altitude,
            'capturedAt': position.timestamp.toUtc().toIso8601String(),
          },
        );
        debugPrint('LocationService: offline buffer\'ga qo\'shildi (status=$code)');
      } else {
        debugPrint(
          'LocationService: backend 4xx xato '
          'status=$code body=${e.response?.data}',
        );
      }
    } catch (e) {
      debugPrint('LocationService: unexpected xato — buffer\'ga: $e');
      await _offlineBuffer.enqueue(
        endpoint: '/location',
        body: <String, dynamic>{
          'childId': _childId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'capturedAt': position.timestamp.toUtc().toIso8601String(),
        },
      );
    }
  }

  /// FCM 'location_wake' push kelganda bitta yangi fix olib yuboradi
  /// (ota-ona xaritani ochdi). Background isolate'da ham ishlaydi —
  /// pairing prefs'dan, token TokenStorage'dan o'qiladi. Best-effort:
  /// hech qachon throw qilmaydi.
  static Future<void> sendWakeFix() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final parentUid = prefs.getString('parentUid');
      final childId = prefs.getString('childId');
      if (parentUid == null || childId == null) return;
      if (!await Permission.locationWhenInUse.isGranted) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 25),
      );
      final service = LocationService()
        .._parentUid = parentUid
        .._childId = childId;
      await service._postToBackend(position);
    } catch (e) {
      debugPrint('LocationService: wake fix yuborilmadi: $e');
    }
  }
}
