// ─────────────────────────────────────────────────────────────────────
// ParentLocationService — OTA-ONA (ushbu qurilma) joylashuvini oladi.
// ─────────────────────────────────────────────────────────────────────
//
// Xaritadagi "mening joylashuvim" tugmasi uchun: ruxsatни so'raydi va joriy
// GPS koordinatasini qaytaradi. Bola joylashuvidан farqli — bu qurilmaning
// (ota-onaning) o'z joyi. Xato/rad holatlari toza status bilan qaytadi (UI
// mos xabar ko'rsatadi).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final parentLocationServiceProvider = Provider<ParentLocationService>((ref) {
  return ParentLocationService();
});

/// Joylashuv olish natijasi holati (UI xabari uchun).
enum MyLocationStatus {
  /// Muvaffaqiyatli — koordinatalar bor.
  ok,

  /// Qurilmada joylashuv xizmati (GPS) o'chiq.
  serviceOff,

  /// Ruxsat berilmadi (yoki butunlay rad etildi).
  denied,

  /// Boshqa xato (timeout / tarmoq / noma'lum).
  error,
}

/// Ota-ona joylashuvi natijasi.
@immutable
class MyLocationResult {
  /// `MyLocationResult` konstruktor.
  const MyLocationResult(this.status, {this.latitude, this.longitude});

  /// Natija holati.
  final MyLocationStatus status;

  /// Koordinatalar (faqat [status] == ok bo'lsa to'ladi).
  final double? latitude;
  final double? longitude;

  /// Muvaffaqiyatli va koordinatalar mavjudmi.
  bool get isOk =>
      status == MyLocationStatus.ok && latitude != null && longitude != null;
}

/// Ota-ona (qurilma) joylashuvini oluvchi xizmat.
class ParentLocationService {
  /// Joriy joylashuvni oladi: xizmat + ruxsat tekshiradi, so'ng GPS fix.
  ///
  /// Hech qачон istisno tashlamaydi — barcha holat [MyLocationResult] bilan
  /// qaytadi.
  Future<MyLocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const MyLocationResult(MyLocationStatus.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const MyLocationResult(MyLocationStatus.denied);
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return MyLocationResult(
        MyLocationStatus.ok,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (e) {
      debugPrint('ParentLocationService.current xato: $e');
      return const MyLocationResult(MyLocationStatus.error);
    }
  }
}
