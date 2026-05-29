// ─────────────────────────────────────────────────────────────────────
// DeviceInfoService — bola qurilma ma'lumotini Firestore'ga yuboruvchi
// ─────────────────────────────────────────────────────────────────────
//
// Pairing tugagach `start()` chaqiriladi: telefon haqida (model, OS,
// batareya, Wi-Fi) ma'lumot yig'iladi va Firestore'ga yoziladi. So'ng
// Timer.periodic orqali har 60 sekundda yangilanadi. `markOffline()`
// — logout/yopish vaqtida `isOnline: false` belgilab, timerni to'xtatadi.

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:farzandim_child/features/device_info/data/models/child_device_info.dart';

class DeviceInfoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();
  final NetworkInfo _networkInfo = NetworkInfo();

  Timer? _updateTimer;
  String? _parentUid;
  String? _childId;

  /// Sprint 4.4.12: Firestore writes butunlay olib tashlandi.
  /// `batteryLevel`/`isCharging` LocationService POST /api/location
  /// ichida yuboriladi — Backend bola obyektini avtomatik yangilaydi.
  /// Bu method legacy — chaqirilsa ham hech narsa qilmaydi.
  Future<void> start({
    required String parentUid,
    required String childId,
  }) async {
    // No-op (Sprint 4.4.12).
    _parentUid = parentUid;
    _childId = childId;
  }

  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Sprint 4.4.12: no-op (Firestore write olib tashlandi).
  Future<void> _sendUpdate() async {
    // Legacy: Firestore'ga deviceInfo yozish endi ishlatilmaydi.
    // Backend POST /api/location ichida batteryLevel + isCharging
    // yuboriladi (LocationService).
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
    } catch (e) {
      // ignore: avoid_print
      print('Device info xato: $e');
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (e) {
      // ignore: avoid_print
      print('Package info xato: $e');
    }

    try {
      batteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      isCharging =
          state == BatteryState.charging || state == BatteryState.full;
    } catch (e) {
      // ignore: avoid_print
      print('Battery xato: $e');
    }

    // Wi-Fi nomi — chuqur diagnostika.
    // Android 9+'da `getWifiName()` ishlash uchun runtime Location ruxsat
    // majburiy. Quyidagi log'lar permission holati, raw SSID/BSSID/IP, va
    // tozalashdan keyingi yakuniy qiymatni ko'rsatadi — bug diagnostikasi.
    try {
      // ignore: avoid_print
      print('=== WIFI DEBUG START ===');

      // 1. Permission tekshirish
      final locationStatus = await Permission.locationWhenInUse.status;
      // ignore: avoid_print
      print('Location.whenInUse status: $locationStatus');

      final locationAlwaysStatus = await Permission.location.status;
      // ignore: avoid_print
      print('Location.location status: $locationAlwaysStatus');

      // 2. Plugin'dan Wi-Fi ma'lumotlari
      try {
        final ssid = await _networkInfo.getWifiName();
        // ignore: avoid_print
        print('Raw SSID: $ssid');

        final bssid = await _networkInfo.getWifiBSSID();
        // ignore: avoid_print
        print('BSSID: $bssid');

        final ip = await _networkInfo.getWifiIP();
        // ignore: avoid_print
        print('IP: $ip');

        // SSID ni tozalash
        if (ssid != null && ssid.isNotEmpty) {
          final cleaned = ssid.replaceAll('"', '').trim();

          if (cleaned == '<unknown ssid>' ||
              cleaned.isEmpty ||
              cleaned == '0x') {
            wifiName = null;
            // ignore: avoid_print
            print('Cleaned SSID is invalid: $cleaned');
          } else {
            wifiName = cleaned;
            // ignore: avoid_print
            print('FINAL Wi-Fi name: $wifiName');
          }
        } else {
          wifiName = null;
          // ignore: avoid_print
          print('SSID is null or empty');
        }
      } catch (e, stack) {
        // ignore: avoid_print
        print('NetworkInfo plugin xatosi: $e');
        // ignore: avoid_print
        print('Stack: $stack');
        wifiName = null;
      }

      // ignore: avoid_print
      print('=== WIFI DEBUG END ===');
    } catch (e) {
      // ignore: avoid_print
      print('Wi-Fi outer xato: $e');
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

  /// Logout yoki ilova yopilganda chaqiriladi — Firestore'da `isOnline: false`.
  Future<void> markOffline() async {
    if (_parentUid == null || _childId == null) {
      stop();
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_parentUid)
          .collection('children')
          .doc(_childId)
          .update({
        'deviceInfo.isOnline': false,
        'deviceInfo.lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('Mark offline xato: $e');
    }

    stop();
  }
}
