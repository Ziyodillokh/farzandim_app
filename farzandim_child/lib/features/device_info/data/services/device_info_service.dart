// ─────────────────────────────────────────────────────────────────────
// DeviceInfoService — bola qurilma ma'lumotini Backend'ga yuboruvchi
// ─────────────────────────────────────────────────────────────────────
//
// Heartbeat (POST /children/:id/device-info): batareya, model, OS, ilova
// versiyasi va OS-ruxsatlar holati. Backend `lastSeenAt` ni yangilaydi —
// ota-ona "online"ni shundan biladi (12 daqiqa), 15 daqiqa jim bo'lsa
// "aloqa uzildi".
//
// Taymer YO'Q. BackgroundJobs chaqiradi:
//   - `sendNow()`   — fon servisi ishga tushganda, `parvoz:location_wake`da;
//   - `sendIfDue()` — 5 daqiqalik tick va ekran yoqilishida: oxirgi
//     muvaffaqiyatdan ≥ 4.5 daqiqa o'tgan YOKI ruxsatlar holati o'zgargan
//     bo'lsa yuboradi.
// Bir vaqtda bitta so'rov.
//
// MUHIM: bu heartbeat GPS/Location'ga BOG'LIQ EMAS.
//
// Ruxsat holatini bilib bo'lmasa (masalan fon dvigatelida UsageStats plagini
// yo'q) maydon YUBORILMAYDI (`null`) — `false` yuborilsa ota-onaga soxta
// "ruxsat o'chirildi" xabari ketardi.

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/background/data/services/background_telemetry.dart';
import 'package:farzandim_child/features/background/data/services/job_timing.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';

/// OS-ruxsat holatlari. `null` = aniqlanmadi (maydon yuborilmaydi).
typedef DevicePermissions = ({
  bool? location,
  bool? notification,
  bool? background,
  bool? accessibility,
  bool? usage,
  bool? overlay,
});

class DeviceInfoService {
  DeviceInfoService({
    Dio? dio,
    UsageStatsService? usageStats,
    DateTime Function()? clock,
  }) : _dio = dio,
       _usageStats = usageStats ?? UsageStatsService(),
       _clock = clock ?? DateTime.now;

  /// Heartbeat oralig'i (5 daqiqalik tick; tebranishga zaxira).
  static const heartbeatInterval = Duration(minutes: 4, seconds: 30);

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();
  final UsageStatsService _usageStats;
  final DateTime Function() _clock;

  Dio? _dio;
  String? _childId;
  Future<void>? _inFlight;
  DateTime? _lastSuccessAt;
  DevicePermissions? _lastSentPermissions;

  /// Model / OS / ilova versiyasi jarayon davomida o'zgarmaydi — bir marta.
  String? _deviceModel;
  String? _osVersion;
  String? _appVersion;
  bool _isStaticInfoLoaded = false;

  /// iOS Ekran vaqti ruxsati — backend'ga oxirgi yuborilgan qiymat. Faqat
  /// o'zgarganda yuboriladi (o'chirilsa ota-onaga ogohlantirish ketadi).
  bool? _sentScreenTimePermission;

  /// Backend `screenTimePermission` maydonini bilmaydi (eski versiya, 400) —
  /// shu sessiyada qayta urinilmaydi.
  bool _isScreenTimeFieldRejected = false;

  // Auth + REFRESH interceptorli umumiy Dio — access token tugasa avtomatik
  // yangilanadi, heartbeat to'xtab qolmaydi.
  Dio _buildDio() => createBackendDio(TokenStorage());

  /// Pairing tugagach / ilova ochilganda: bola ID'si va darhol bitta
  /// heartbeat (kutilmaydi — ishga tushish tarmoqqa bog'lanmaydi).
  Future<void> start({
    required String parentUid, // saqlanmaydi — API mosligi uchun
    required String childId,
  }) async {
    _childId = childId;
    unawaited(sendNow());
  }

  /// Taymer yo'q — API mosligi uchun.
  void stop() {}

  /// Logout / unpair: online holat backend'da `lastSeenAt` eskirishi orqali
  /// avtomatik "offline" bo'ladi.
  Future<void> markOffline() async {
    _childId = null;
  }

  /// Darhol heartbeat (bir vaqtda bitta).
  Future<void> sendNow() => _send();

  /// Muddati kelgan (≥ 4.5 daq) yoki ruxsatlar holati o'zgargan bo'lsa.
  Future<void> sendIfDue() async {
    if (_childId == null) return;
    final running = _inFlight;
    if (running != null) return running;
    final permissions = await _collectPermissions();
    final hasChanged = permissions != _lastSentPermissions;
    if (!hasChanged && !isDue(_lastSuccessAt, _clock(), heartbeatInterval)) {
      return;
    }
    await _send(permissions: permissions);
  }

  Future<void> _send({DevicePermissions? permissions}) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _doSend(permissions).whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  /// Qurilma ma'lumotini yig'ib Backend'ga POST qiladi (GPS'siz).
  Future<void> _doSend(DevicePermissions? known) async {
    final childId = _childId;
    if (childId == null) return;
    final dio = _dio ??= _buildDio();
    final startedAt = _clock();
    try {
      await _loadStaticInfo();
      final perms = known ?? await _collectPermissions();
      final battery = await _readBattery();
      final body = <String, dynamic>{
        if (battery.level != null) 'batteryLevel': battery.level,
        if (battery.isCharging != null) 'isCharging': battery.isCharging,
        if (_deviceModel != null) 'deviceModel': _deviceModel,
        if (_osVersion != null) 'androidVersion': _osVersion,
        if (_appVersion != null) 'appVersion': _appVersion,
        // `wifiName` ATAYLAB yuborilmaydi — Google Play Families siyosati
        // SSID uzatishni taqiqlaydi (2026-08-17 rad javobi).
        // OS-ruxsat holatlari (Block 4 / M12) — ota-onaga ko'rsatish uchun.
        if (perms.location != null) 'locationPermission': perms.location,
        if (perms.notification != null)
          'notificationPermission': perms.notification,
        if (perms.background != null) 'backgroundAllowed': perms.background,
        if (perms.accessibility != null)
          'accessibilityEnabled': perms.accessibility,
        // Ekran vaqti / ilova statistikasi shu ruxsatsiz yig'ilmaydi.
        if (perms.usage != null) 'usagePermission': perms.usage,
        // Blok ekrani (overlay) shu ruxsatsiz chiqmaydi.
        if (perms.overlay != null) 'overlayPermission': perms.overlay,
      };
      await dio.post<void>('/children/$childId/device-info', data: body);
      _lastSuccessAt = startedAt;
      _lastSentPermissions = perms;
    } on DioException catch (e) {
      debugPrint('DeviceInfo heartbeat xato: ${e.response?.statusCode}');
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'deviceInfo.send');
    }
    await _sendScreenTimePermission(dio, childId);
  }

  /// iOS: Family Controls ruxsati holati ALOHIDA so'rovda — backend hali bu
  /// maydonni bilmasa (forbidNonWhitelisted → 400) asosiy heartbeat yiqilmasin
  /// (aks holda ota-onaga soxta "aloqa uzildi" ketardi).
  Future<void> _sendScreenTimePermission(Dio dio, String childId) async {
    if (!PlatformCapabilities.isIOS || _isScreenTimeFieldRejected) return;
    final bool isAuthorized;
    try {
      isAuthorized = (await const ScreenTimeChannel().status()).isAuthorized;
    } catch (_) {
      return;
    }
    if (isAuthorized == _sentScreenTimePermission) return;
    try {
      await dio.post<void>(
        '/children/$childId/device-info',
        data: {'screenTimePermission': isAuthorized},
      );
      _sentScreenTimePermission = isAuthorized;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) _isScreenTimeFieldRejected = true;
      debugPrint(
        'DeviceInfo screenTimePermission xato: ${e.response?.statusCode}',
      );
    }
  }

  Future<void> _loadStaticInfo() async {
    if (_isStaticInfoLoaded) return;
    var isComplete = true;
    try {
      if (PlatformCapabilities.isIOS) {
        // Backend maydoni `androidVersion` — ota-onada "OS versiyasi".
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceModel = iosInfo.modelName;
        _osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        _osVersion = 'Android ${androidInfo.version.release}';
      }
    } catch (_) {
      isComplete = false;
    }
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      isComplete = false;
    }
    // ⚠️ Wi-Fi nomi (SSID) YIG'ILMAYDI — Google Play "Families Device
    // Identifiers" siyosati. Qayta tiklamang.
    _isStaticInfoLoaded = isComplete;
  }

  Future<({int? level, bool? isCharging})> _readBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return (
        level: level,
        isCharging:
            state == BatteryState.charging || state == BatteryState.full,
      );
    } catch (_) {
      return (level: null, isCharging: null);
    }
  }

  /// OS-ruxsat holatlarini yig'adi. Har biri mustaqil — biri xato bersa
  /// boshqalari baribir yuboriladi. `null` = aniqlanmadi.
  Future<DevicePermissions> _collectPermissions() async {
    Future<bool?> safe(Future<bool?> Function() check) async {
      try {
        return await check();
      } catch (_) {
        return null;
      }
    }

    // iOS'da batareya optimizatsiyasi, Accessibility va UsageStats yo'q —
    // `null` = maydon yuborilmaydi.
    final hasAndroidControls = PlatformCapabilities.hasAndroidControls;
    return (
      // Background kuzatuv uchun tizim ASLIDA talab qiladigan ruxsat —
      // locationAlways ("Har doim").
      location: await safe(() => Permission.locationAlways.isGranted),
      notification: await safe(() => Permission.notification.isGranted),
      background: hasAndroidControls
          ? await safe(() => Permission.ignoreBatteryOptimizations.isGranted)
          : null,
      accessibility: hasAndroidControls
          ? await safe(_usageStats.tryIsAccessibilityEnabled)
          : null,
      // PACKAGE_USAGE_STATS — ekran vaqti manbasi. Plagin yo'q → `null`.
      usage: hasAndroidControls
          ? await safe(_usageStats.tryHasPermission)
          : null,
      // SYSTEM_ALERT_WINDOW — "Boshqa ilovalar ustidan ko'rsatish".
      overlay: hasAndroidControls
          ? await safe(() => Permission.systemAlertWindow.isGranted)
          : null,
    );
  }
}
