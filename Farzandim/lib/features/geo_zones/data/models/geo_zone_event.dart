import 'package:flutter/foundation.dart';

/// Geo-zona event turi: bola zonaga kirdimi yoki chiqdimi.
enum GeoZoneEventType {
  /// Zonaga kirdi.
  enter,

  /// Zonadan chiqdi.
  exit,
}

/// `GeoZoneEventType` uchun foydalanuvchi-friendly o'zbekcha matnlar.
extension GeoZoneEventTypeExt on GeoZoneEventType {
  /// Qisqa label — "kirdi" / "chiqdi" (filter, badge).
  String get label {
    switch (this) {
      case GeoZoneEventType.enter:
        return 'kirdi';
      case GeoZoneEventType.exit:
        return 'chiqdi';
    }
  }

  /// Sentence verb — "keldi" / "ketdi" ("Aliy maktab ga keldi").
  String get verb {
    switch (this) {
      case GeoZoneEventType.enter:
        return 'keldi';
      case GeoZoneEventType.exit:
        return 'ketdi';
    }
  }
}

/// Bola zonaga kirish/chiqish event'i.
///
/// Child App `geo_zone_events` top-level collection'iga yozadi
/// (Bosqich 2). Parent App shu yerdan stream o'qib tarix ekran'da
/// ko'rsatadi.
///
/// **Firestore strukturasi:** `geo_zone_events/{auto-id}` —
/// `parentUid` + `childId` indekslangan (Parent App query). Top-level
/// (subcollection emas) — Cloud Function trigger'lar uchun qulay.
@immutable
class GeoZoneEvent {
  /// `GeoZoneEvent` konstruktor.
  const GeoZoneEvent({
    required this.id,
    required this.parentUid,
    required this.childId,
    required this.childName,
    required this.zoneId,
    required this.zoneName,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  /// Backend `/children/:id/geo-zone-events` javobidan parse qiladi.
  /// Backend childName/parentUid bermaydi — per-child ekran uchun kerak emas.
  factory GeoZoneEvent.fromBackendJson(
    Map<String, dynamic> json, {
    required String childId,
  }) {
    final typeStr = json['type'] as String? ?? 'enter';
    return GeoZoneEvent(
      id: json['id'] as String? ?? '',
      parentUid: '',
      childId: childId,
      childName: '',
      zoneId: json['zoneId'] as String? ?? '',
      zoneName: json['zoneName'] as String? ?? '',
      eventType: typeStr == 'exit'
          ? GeoZoneEventType.exit
          : GeoZoneEventType.enter,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      // Backend UTC ("Z") — .toLocal()'siz voqea vaqtlari Toshkentda 5 soat
      // orqada ko'rinardi (P0-5).
      timestamp:
          (DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                  DateTime.now())
              .toLocal(),
    );
  }

  /// Firestore document ID.
  final String id;

  /// Ota-ona Firebase UID — query filter va auth qoidalari uchun.
  final String parentUid;

  /// Qaysi bola event'i.
  final String childId;

  /// Bola ismi (denormalized — list ekranida har event'da
  /// alohida bola hujjatini o'qimaslik uchun).
  final String childName;

  /// Qaysi zona event'i.
  final String zoneId;

  /// Zona nomi (denormalized — zona o'chirilsa ham tarix ko'rinadi).
  final String zoneName;

  /// Event turi: kirdi (`enter`) yoki chiqdi (`exit`).
  final GeoZoneEventType eventType;

  /// Event yuz bergan joyning kengligi (xaritada belgilash uchun).
  final double latitude;

  /// Event yuz bergan joyning uzunligi.
  final double longitude;

  /// Event vaqti (server timestamp).
  final DateTime timestamp;
}
