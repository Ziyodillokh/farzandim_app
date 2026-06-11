import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bola joriy joylashuvi.
///
/// Child App `users/{parentUid}/children/{childId}` doc'iga `location`
/// field sifatida yozadi (schema: latitude, longitude, accuracy, heading,
/// speed, updatedAt). Parent App shu maydonni snapshot stream orqali
/// kuzatadi va xaritada real-vaqt pin ko'rsatadi.
@immutable
class ChildLocation {
  /// `ChildLocation` konstruktor.
  const ChildLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
    this.heading,
    this.speed,
  });

  /// Backend REST `Location` JSON'idan o'qish (Sprint 4.4.2).
  ///
  /// Backend kontrakt (Prisma `Location` model):
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "childId": "uuid",
  ///   "latitude": 41.36,
  ///   "longitude": 69.29,
  ///   "accuracy": 5.2,         // optional
  ///   "speed": 1.2,             // optional
  ///   "batteryLevel": 78,       // optional, this model ignoradi
  ///   "isCharging": false,      // optional, this model ignoradi
  ///   "createdAt": "ISO 8601"
  /// }
  /// ```
  ///
  /// Backend'da `heading` field yo'q — `null` qoldiriladi.
  factory ChildLocation.fromBackendJson(Map<String, dynamic> json) {
    return ChildLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      // Backend UTC ("Z") qaytaradi — .toLocal()'siz tarix vaqtlari
      // Toshkentda 5 soat orqada ko'rinardi (P0-5).
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
