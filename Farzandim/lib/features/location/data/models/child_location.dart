import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;

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
    // Himoyalangan parsing — avval `latitude/longitude` hard cast va
    // `DateTime.parse(... as String)` edi: bitta buzuq yozuv (null koordinata
    // yoki noto'g'ri sana) `on DioException` catch'idan o'tib ketib, BUTUN
    // ro'yxatni (tarix/live) xato holatiga tushirardi. Sibling modellar
    // (LocationStop/GeoZoneEvent) kabi endi hech qachon exception tashlamaydi.
    final rawTs = json['capturedAt'] ?? json['createdAt'];
    final parsedTs = rawTs is String ? DateTime.tryParse(rawTs) : null;
    return ChildLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      // Backend UTC ("Z") qaytaradi — .toLocal() qilmasak vaqtlar
      // Toshkentda 5 soat orqada ko'rinadi. capturedAt — nuqtaning haqiqiy
      // fix vaqti (offline flush'da createdAt server vaqti bo'lib qoladi).
      updatedAt: parsedTs?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
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
