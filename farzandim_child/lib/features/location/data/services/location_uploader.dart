// ─────────────────────────────────────────────────────────────────────
// LocationUploader — joylashuv nuqtasini backend'ga yuborish
// ─────────────────────────────────────────────────────────────────────
//
// POST /location (JWT, refresh interceptorli umumiy Dio — createBackendDio).
// Backend Postgres'ga yozadi, geofence va to'xtash joylarini aniqlaydi,
// ota-onaga push yuboradi. Tarmoq xatosi / 5xx — offline buffer'ga;
// 4xx (validatsiya) — tashlanadi. Hech qachon throw qilmaydi.
//
// Koordinatalar va javob tanasi log'ga YOZILMAYDI (bola joylashuvi —
// maxfiy; geofence hodisalarida joy nomlari bor).

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';
import 'package:farzandim_child/features/location/data/services/location_strategy.dart';

/// Nuqtani backend'ga yetkazuvchi (testlarda soxtasi qo'yiladi).
abstract interface class LocationUploader {
  /// Hech qachon throw qilmaydi.
  Future<void> post({required String childId, required LocationSample sample});
}

class BackendLocationUploader implements LocationUploader {
  BackendLocationUploader({Dio? dio, OfflineBuffer? offlineBuffer})
    : _dioOverride = dio,
      _bufferOverride = offlineBuffer;

  final Dio? _dioOverride;
  final OfflineBuffer? _bufferOverride;

  // Auth + REFRESH interceptorli (createBackendDio): 15-daqiqalik access
  // token tugasa background isolate'da ham avtomatik yangilanadi.
  late final Dio _dio = _dioOverride ?? createBackendDio(TokenStorage());
  late final OfflineBuffer _offlineBuffer = _bufferOverride ?? OfflineBuffer();

  // Sprint 4.4.23: device info Backend'ga POST /location ichida ketadi.
  bool _deviceInfoLoaded = false;
  String? _deviceModel;
  String? _androidVersion;
  String? _appVersion;

  // ⚠️ Wi-Fi nomi (SSID) BU YERDA YIG'ILMAYDI — 2026-08-17 Google Play
  // "Families Device Identifiers" rad javobi. Faqat bolalarga mo'ljallangan
  // ilova SSID/BSSID/AAID/IMEI kabi identifikatorlarni uzatishi TAQIQLANADI.
  // Ilgari `NetworkInfo().getWifiName()` natijasi `/location` so'roviga
  // `wifiName` bo'lib qo'shilardi. Qayta tiklamang.
  // Qarang: https://support.google.com/googleplay/android-developer/answer/9893335

  @override
  Future<void> post({
    required String childId,
    required LocationSample sample,
  }) async {
    try {
      final payload = <String, dynamic>{
        ..._pointBody(childId, sample),
        ...await _deviceExtras(),
      };
      final response = await _dio.post<Map<String, dynamic>>(
        '/location',
        data: payload,
      );
      final events = response.data?['geofenceEvents'];
      debugPrint(
        'LocationService: location yozildi (Backend)'
        '${events is List && events.isNotEmpty ? ', geofence: ${events.length}' : ''}',
      );
    } on DioException catch (e) {
      // Tarmoq xato, 5xx yoki vaqtinchalik 401/408/429 (token yangilanmoqda,
      // tarmoq sekin, limit) — offline buffer'ga (u ham shularni vaqtinchalik
      // deb biladi); boshqa 4xx (validatsiya) — foydasiz, faqat log.
      final code = e.response?.statusCode ?? 0;
      if (code == 0 || code >= 500 || code == 401 || code == 408 || code == 429) {
        await _enqueue(_pointBody(childId, sample));
        debugPrint(
          "LocationService: offline buffer'ga qo'shildi (status=$code)",
        );
      } else {
        debugPrint('LocationService: backend 4xx xato status=$code');
      }
    } catch (e) {
      debugPrint(
        "LocationService: kutilmagan xato (${e.runtimeType}) — buffer'ga",
      );
      await _enqueue(_pointBody(childId, sample));
    }
  }

  /// Nuqtaning o'zi. `capturedAt` — nuqtaning O'Z vaqti (fix vaqti):
  /// "tirikman" yoki offline flush bo'lsa ham backend to'g'ri vaqtni oladi.
  Map<String, dynamic> _pointBody(String childId, LocationSample s) => {
    'childId': childId,
    'latitude': s.latitude,
    'longitude': s.longitude,
    'accuracy': s.accuracyM,
    'speed': s.speedMps,
    'heading': s.headingDeg,
    'altitude': s.altitudeM,
    'capturedAt': s.at.toUtc().toIso8601String(),
  };

  /// Batareya va qurilma ma'lumoti (Sprint 4.4.12 / 4.4.23) — xato bo'lsa
  /// tushirib qoldiriladi.
  Future<Map<String, dynamic>> _deviceExtras() async {
    int? batteryLevel;
    bool? isCharging;
    try {
      final battery = Battery();
      batteryLevel = await battery.batteryLevel;
      final state = await battery.batteryState;
      isCharging = state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      // Battery plugin xato — skip
    }
    await _loadDeviceInfo();
    return {
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (isCharging != null) 'isCharging': isCharging,
      if (_deviceModel != null) 'deviceModel': _deviceModel,
      if (_androidVersion != null) 'androidVersion': _androidVersion,
      if (_appVersion != null) 'appVersion': _appVersion,
      // `wifiName` ATAYLAB yuborilmaydi — Families siyosati (yuqoriga qarang).
    };
  }

  Future<void> _loadDeviceInfo() async {
    if (_deviceInfoLoaded) return;
    _deviceInfoLoaded = true;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _deviceModel = '${info.brand} ${info.model}';
      _androidVersion = 'Android ${info.version.release}';
    } catch (_) {
      // iOS yoki plugin xato — skip
    }
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // skip
    }
  }

  Future<void> _enqueue(Map<String, dynamic> body) async {
    try {
      await _offlineBuffer.enqueue(endpoint: '/location', body: body);
    } catch (e) {
      debugPrint('LocationService: buffer xato (${e.runtimeType})');
    }
  }
}
