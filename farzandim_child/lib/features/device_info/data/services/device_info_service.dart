// ─────────────────────────────────────────────────────────────────────
// DeviceInfoService — bola qurilma ma'lumotini Backend'ga yuboruvchi
// ─────────────────────────────────────────────────────────────────────
//
// Pairing tugagach `start()` chaqiriladi: telefon haqida (model, OS,
// batareya, Wi-Fi) ma'lumot yig'iladi va DARHOL Backend'ga yuboriladi,
// so'ng Timer.periodic orqali har 60 sekundda yangilanadi.
//
// MUHIM: bu heartbeat GPS/Location'ga BOG'LIQ EMAS. Avval qurilma
// ma'lumoti faqat LocationService POST /location ichida yuborilardi —
// agar bola Location ruxsatini bermasa yoki GPS o'chiq bo'lsa, ota-ona
// "Noma'lum qurilma" ko'rardi. Endi bu alohida, ruxsatsiz heartbeat.
//
// Online holat: backend `lastSeenAt` ni yangilaydi; ota-ona App online'ni
// shu vaqt yangiligiga qarab aniqlaydi (heartbeat to'xtasa → offline).

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/features/device_info/data/models/child_device_info.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();
  final NetworkInfo _networkInfo = NetworkInfo();
  final TokenStorage _tokenStorage = TokenStorage();

  Timer? _updateTimer;
  Dio? _dio;
  String? _childId;

  /// Heartbeat oralig'i — har 20 sek (batareya/zaryadlanish deyarli real-time
  /// yangilanishi uchun). Ota-ona ekranida ham 10s'da bir qayta o'qiladi.
  static const Duration _interval = Duration(seconds: 20);

  Dio _buildDio() {
    return Dio(
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
  }

  /// Pairing tugagach chaqiriladi — darhol bir heartbeat + davriy timer.
  Future<void> start({
    required String parentUid, // saqlanmaydi — API mosligi uchun
    required String childId,
  }) async {
    _childId = childId;
    _dio ??= _buildDio();

    await _sendUpdate(); // darhol — "Noma'lum qurilma" ni tezda to'g'rilaydi

    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      _interval,
      (_) => unawaited(_sendUpdate()),
    );
  }

  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Qurilma ma'lumotini yig'ib Backend'ga POST qiladi (GPS'siz).
  Future<void> _sendUpdate() async {
    final childId = _childId;
    final dio = _dio;
    if (childId == null || dio == null) return;
    try {
      final info = await _collectDeviceInfo();
      final body = <String, dynamic>{
        if (info.batteryLevel != null) 'batteryLevel': info.batteryLevel,
        if (info.isCharging != null) 'isCharging': info.isCharging,
        if (info.deviceModel != null) 'deviceModel': info.deviceModel,
        if (info.androidVersion != null) 'androidVersion': info.androidVersion,
        if (info.appVersion != null) 'appVersion': info.appVersion,
        if (info.wifiName != null) 'wifiName': info.wifiName,
      };
      await dio.post<void>('/children/$childId/device-info', data: body);
    } catch (e) {
      // ignore: avoid_print
      print('DeviceInfo heartbeat xato: $e');
    }
  }

  Future<ChildDeviceInfo> _collectDeviceInfo() async {
    String? deviceModel;
    String? androidVersion;
    String? appVersion;
    int? batteryLevel;
    bool? isCharging;
    String? wifiName;

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      androidVersion = 'Android ${androidInfo.version.release}';
    } catch (_) {
      // iOS yoki plugin xato — skip
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (_) {
      // skip
    }

    try {
      batteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      isCharging =
          state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      // skip
    }

    // Wi-Fi nomi — Android 9+'da Location ruxsati kerak; yo'q bo'lsa null
    // qoladi (bu boshqa maydonlarni to'sib qo'ymaydi).
    try {
      final ssid = await _networkInfo.getWifiName();
      if (ssid != null && ssid.isNotEmpty) {
        final cleaned = ssid.replaceAll('"', '').trim();
        if (cleaned != '<unknown ssid>' &&
            cleaned.isNotEmpty &&
            cleaned != '0x') {
          wifiName = cleaned;
        }
      }
    } catch (_) {
      wifiName = null;
    }

    return ChildDeviceInfo(
      deviceModel: deviceModel,
      androidVersion: androidVersion,
      appVersion: appVersion,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      wifiName: wifiName,
      isOnline: true,
    );
  }

  /// Logout yoki ilova yopilganda — timerni to'xtatadi. Online holat
  /// backend'da `lastSeenAt` eskirishi orqali avtomatik "offline" bo'ladi.
  Future<void> markOffline() async {
    stop();
  }
}
