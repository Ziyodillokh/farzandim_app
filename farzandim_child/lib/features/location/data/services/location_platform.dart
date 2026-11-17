// ─────────────────────────────────────────────────────────────────────
// LocationPlatform — geolocator va fon servisi bilan aloqa (LocationService)
// ─────────────────────────────────────────────────────────────────────
//
// Hech biri throw qilmaydi (xato — null/false). Koordinatalar log'ga
// YOZILMAYDI.

import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:farzandim_child/features/location/data/services/location_sample.dart';

abstract final class LocationPlatform {
  /// Rejimga mos oqim sozlamasi.
  static LocationSettings settingsFor(LocationMode mode) {
    final spec = StreamSpec.of(mode);
    final accuracy = spec.highAccuracy
        ? LocationAccuracy.high
        : LocationAccuracy.medium;
    if (PlatformCapabilities.isAndroid) {
      // medium → PRIORITY_BALANCED_POWER_ACCURACY (GNSS'siz), useMSLAltitude
      // o'chiq. geolocator_android 4.6.2 NMEA/GNSS-status tinglovchisini har
      // so'rovda ulaydi (o'chirish sozlamasi yo'q) — GNSS o'chiq paytda ular
      // jim, faqat safar (GPS) rejimida ishlaydi.
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: spec.distanceFilterM,
        intervalDuration: spec.interval,
      );
    }
    if (PlatformCapabilities.isIOS) {
      // Fon joylashuvi avvalgidek: UIBackgroundModes `location`,
      // fon yangilanishi yoqiq, avto-pauza o'chiq.
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: spec.distanceFilterM,
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: spec.distanceFilterM,
    );
  }

  static Stream<Position> positions(LocationMode mode) =>
      Geolocator.getPositionStream(locationSettings: settingsFor(mode));

  /// Bitta fix ([limit] ichida) yoki null.
  static Future<LocationSample?> oneShot(
    LocationAccuracy accuracy,
    Duration limit,
  ) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: limit,
      ).timeout(limit + const Duration(seconds: 5));
      return sampleOf(p);
    } catch (e) {
      debugPrint('LocationService: ${accuracy.name} fix olinmadi: $e');
      return null;
    }
  }

  /// OS keshidagi oxirgi joy (yangi fix so'ramaydi — bepul).
  static Future<LocationSample?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : sampleOf(p);
    } catch (e) {
      debugPrint("LocationService: oxirgi ma'lum joy o'qilmadi: $e");
      return null;
    }
  }

  /// Ruxsat bor va joylashuv xizmati yoqiq.
  static Future<bool> isUsable({bool logState = false}) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (logState) {
          debugPrint(
            "LocationService: ruxsat yo'q ($permission) — tick kutadi",
          );
        }
        return false;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (logState) debugPrint("LocationService: GPS o'chiq — tick kutadi");
        return false;
      }
      if (logState && permission != LocationPermission.always) {
        // Android 11+: fon fix uchun "Har doim" kerak bo'lishi mumkin.
        debugPrint('LocationService: faqat while-in-use ruxsat');
      }
      return true;
    } catch (e) {
      debugPrint('LocationService: ruxsat tekshirilmadi: $e');
      return false;
    }
  }

  /// iOS "while in use": fonda oqimni qayta ochib bo'lmaydi — rejim
  /// almashuvi faqat ilova ochiq yoki "Har doim" ruxsatida. Android — doim.
  static Future<bool> canSwitchStreamNow() async {
    if (!PlatformCapabilities.isIOS) return true;
    try {
      if (SchedulerBinding.instance.lifecycleState ==
          AppLifecycleState.resumed) {
        return true;
      }
    } catch (_) {
      // Binding yo'q — fonda deb hisoblaymiz.
    }
    try {
      return await Geolocator.checkPermission() == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Android: fon servisi ishlayotgan bo'lsa wake unga uzatiladi
  /// (joylashuv egasi — FGS isolate). Uzatildi — true.
  static Future<bool> forwardWakeToForegroundTask() async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      if (!await FlutterForegroundTask.isRunningService) return false;
      FlutterForegroundTask.sendDataToTask(ParvozMessages.locationWake);
      debugPrint('LocationService: wake fon servisiga uzatildi');
      return true;
    } catch (e) {
      debugPrint('LocationService: fon servisi tekshirilmadi: $e');
      return false;
    }
  }

  static LocationSample sampleOf(Position p) => LocationSample(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyM: p.accuracy,
    at: p.timestamp,
    speedMps: p.speed,
    speedAccuracyMps: p.speedAccuracy,
    headingDeg: p.heading,
    altitudeM: p.altitude,
  );
}
