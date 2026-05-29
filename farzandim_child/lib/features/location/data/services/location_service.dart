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

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';

class LocationService {
  // ─── Backend Dio (Sprint 4.4) ─────────────────────────────────────
  // Self-contained — main + background isolate'da bir xil ishlaydi.
  // Token har request'da TokenStorage'dan o'qiladi (refresh interceptor
  // emas — LocationService o'zi ishlamoqda paytida token refresh
  // boshqa joyda boshqariladi).
  late final Dio _dio = _buildDio();
  final TokenStorage _tokenStorage = TokenStorage();
  final OfflineBuffer _offlineBuffer = OfflineBuffer();

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await _tokenStorage.readAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
    return dio;
  }

  // Firestore field olib tashlandi — Backend POST /location ishlatamiz.

  /// Heartbeat oralig'i — bola harakatlanmagan paytda ham har shu
  /// vaqtda Firestore'ga oxirgi pozitsiyani yozadi (tarix bo'sh
  /// qolmasligi uchun). Konsept: 10m+ harakat YOKI 10 daqiqa heartbeat.
  static const Duration _heartbeatInterval = Duration(minutes: 10);

  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
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

    // 1. Permission tekshirish
    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      debugPrint(
          'LocationService: ruxsat yo\'q ($status) — start to\'xtatildi');
      return;
    }

    // 2. Service yoqilganligini tekshirish (GPS o'chiq bo'lishi mumkin)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: GPS service o\'chiq');
      return;
    }

    // 2b. Geo zone watcher Sprint 4.4'da olib tashlandi — Backend
    // POST /location'da geofence avtomatik aniqlanadi va parent'ga
    // FCM push yuboradi. Lokal watcher'ga zarurat yo'q.

    // 3. Cached pozitsiya bo'lsa darhol yoz (sync, fast).
    // `getLastKnownPosition()` OS keshidan oxirgi ma'lum joylashuvni
    // qaytaradi — fix talab qilmaydi, shuning uchun osilmaydi.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await _writeToFirestore(lastKnown);
      }
    } catch (e) {
      debugPrint('LocationService getLastKnownPosition error: $e');
    }

    // 4. Stream'ga obuna — har 10m harakatda yangi pozitsiya.
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
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

    // 6. Heartbeat timer — har 10 daqiqada oxirgi pozitsiyani yana
    // yozadi (bola statsionar bo'lsa ham tarix bo'sh qolmasin).
    // `distanceFilter: 10` stream emit qilmaydi → bu yagona yo'l.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (_lastPosition != null) {
        debugPrint('LocationService: heartbeat tick');
        await _writeToFirestore(_lastPosition!);
      } else {
        // Hali hech qanday pozitsiya yo'q — yangi fix so'rash.
        debugPrint('LocationService: heartbeat — _lastPosition null, fresh fix');
        unawaited(_forceFirstFix());
      }
    });
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

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
        // Client-side timestamp — Backend offline buffer flush paytida
        // location qachon olinganini biladi (server timestamp emas).
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
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
            'capturedAt': DateTime.now().toUtc().toIso8601String(),
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
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }
  }
}
