import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bola joriy joylashuvi.
///
/// Backend'dan REST/WS orqali keladi, xaritada real-vaqt pin
/// ko'rsatish uchun ishlatiladi.
@immutable
class ChildLocation {
  const ChildLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
    this.heading,
    this.speed,
  });

  /// Backend `Location` JSON'idan o'qish.
  ///
  /// `accuracy`/`speed` ixtiyoriy; `batteryLevel`/`isCharging` bu modelga
  /// kerak emas. Backend'da `heading` yo'q — `null` qoladi.
  factory ChildLocation.fromBackendJson(Map<String, dynamic> json) {
    return ChildLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      // Backend UTC ("Z") qaytaradi — .toLocal() qilmasak vaqtlar
      // Toshkentda 5 soat orqada ko'rinadi.
      updatedAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  /// Kenglik (latitude).
  final double latitude;

  /// Uzunlik (longitude).
  final double longitude;

  /// GPS aniqligi metrlarda (kichikroq = aniqroq).
  final double accuracy;

  /// Joylashuv server'da yangilangan vaqt.
  final DateTime updatedAt;

  /// Yo'nalish darajalarda (0–360, ixtiyoriy).
  final double? heading;

  /// Tezlik m/s (ixtiyoriy).
  final double? speed;

  /// Bola harakatlanyaptimi — 1 m/s'dan tez bo'lsa "harakatda".
  bool get isMoving => (speed ?? 0) > 1;

  /// Google Maps `LatLng` formatiga o'tkazadi.
  LatLng get latLng => LatLng(latitude, longitude);
}
