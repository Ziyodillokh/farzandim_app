import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geo-zona kategoriyasi — kelajak biznes-mantiq uchun (default radius,
/// ikona tavsiyasi, filtering).
enum GeoZoneType {
  /// Uy.
  home,

  /// Maktab.
  school,

  /// Sport zal / mashg'ulot joyi.
  sport,

  /// Boshqa (default).
  custom,
}

/// `GeoZoneType` uchun foydalanuvchi-friendly label.
extension GeoZoneTypeExt on GeoZoneType {
  /// O'zbekcha label — UI'da type tag/picker uchun.
  String get label {
    switch (this) {
      case GeoZoneType.home:
        return 'Uy';
      case GeoZoneType.school:
        return 'Maktab';
      case GeoZoneType.sport:
        return 'Sport zal';
      case GeoZoneType.custom:
        return 'Boshqa';
    }
  }

  /// Tavsiya etilgan default ikon nomi (`GeoZone.icon`'ga mos).
  String get defaultIconName {
    switch (this) {
      case GeoZoneType.home:
        return 'home';
      case GeoZoneType.school:
        return 'school';
      case GeoZoneType.sport:
        return 'sports';
      case GeoZoneType.custom:
        return 'place';
    }
  }
}

/// Geo-zona — xaritada belgilangan dumaloq hudud (Uy, Maktab, va h.k.).
///
/// Bola Child App'dan yuborayotgan joylashuv shu hudud ichiga kirsa
/// yoki chiqsa (`notifyOnEnter` / `notifyOnExit` yoqilgan bo'lsa),
/// ota-onaga push xabar boradi.
///
/// **Firestore:** `users/{parentUid}/children/{childId}/geo_zones/{id}`
/// subcollection. Har bola alohida zonalarga ega.
@immutable
class GeoZone {
  /// `GeoZone` konstruktor.
  const GeoZone({
    required this.id,
    required this.parentUid,
    required this.childId,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.notifyOnEnter,
    required this.notifyOnExit,
    required this.createdAt,
    required this.updatedAt,
    this.icon,
  });

  /// Backend REST `GeoZone` JSON'idan parse (Sprint 4.4.3).
  ///
  /// Backend kontract (Prisma `GeoZone` model):
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "childId": "uuid",
  ///   "name": "Maktab",
  ///   "centerLat": 41.3611,
  ///   "centerLng": 69.2875,
  ///   "radiusMeters": 250,
  ///   "alertOnEnter": true,
  ///   "alertOnExit": true,
  ///   "isActive": true,
  ///   "createdAt": "ISO 8601"
  /// }
  /// ```
  ///
  /// Mapping (Backend → Frontend):
  /// - `centerLat/centerLng` → `latitude/longitude`
  /// - `alertOnEnter/Exit` → `notifyOnEnter/Exit`
  ///
  /// `type` va `icon` Backend'da yo'q — `GeoZoneType.custom` + name'dan
  /// taxmin qilamiz. `parentUid` ham yo'q — caller (`currentUserId`)
  /// dan keladi. `updatedAt` Backend'da yo'q — `createdAt` ishlatamiz.
  factory GeoZone.fromBackendJson(
    Map<String, dynamic> json, {
    required String parentUid,
  }) {
    final name = (json['name'] as String?) ?? '';
    return GeoZone(
      id: json['id'] as String? ?? '',
      parentUid: parentUid,
      childId: json['childId'] as String? ?? '',
      name: name,
      type: _guessTypeFromName(name),
      latitude: (json['centerLat'] as num?)?.toDouble() ?? 0,
      longitude: (json['centerLng'] as num?)?.toDouble() ?? 0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 100,
      notifyOnEnter: json['alertOnEnter'] as bool? ?? true,
      notifyOnExit: json['alertOnExit'] as bool? ?? true,
      createdAt: _parseBackendIso(json['createdAt'] as String?) ??
          DateTime.now(),
      updatedAt: _parseBackendIso(json['createdAt'] as String?) ??
          DateTime.now(),
    );
  }

  /// Backend'ga JSON yuborish uchun (POST/PUT).
  /// Backend faqat shu fieldlarni qabul qiladi.
  Map<String, dynamic> toBackendJson() {
    return {
      'name': name,
      'centerLat': latitude,
      'centerLng': longitude,
      'radiusMeters': radiusMeters.toInt(),
      'alertOnEnter': notifyOnEnter,
      'alertOnExit': notifyOnExit,
    };
  }

  /// Name'dan zona turini taxmin qilish (heuristic).
  static GeoZoneType _guessTypeFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('uy') || n.contains('home') || n.contains('дом')) {
      return GeoZoneType.home;
    }
    if (n.contains('maktab') ||
        n.contains('school') ||
        n.contains('школа')) {
      return GeoZoneType.school;
    }
    if (n.contains('sport') || n.contains('gym')) {
      return GeoZoneType.sport;
    }
    return GeoZoneType.custom;
  }

  static DateTime? _parseBackendIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Firestore document ID (write paytida bo'sh, server beradi).
  final String id;

  /// Ota-ona Firebase UID — query filter va Storage path uchun.
  final String parentUid;

  /// Qaysi bola uchun zona (per-child).
  final String childId;

  /// Zona nomi — "Uy", "Maktab", va h.k.
  final String name;

  /// Zona kategoriyasi (default `custom`).
  final GeoZoneType type;

  /// Markaz koordinatasi: kenglik (Toshkent atrofida ~41°).
  final double latitude;

  /// Markaz koordinatasi: uzunlik (Toshkent atrofida ~69°).
  final double longitude;

  /// Radius (metr). Slider 50-500m oralig'ida tanlatadi.
  final double radiusMeters;

  /// Bola zonaga **kirsa** push xabar yuborilsinmi.
  final bool notifyOnEnter;

  /// Bola zonadan **chiqsa** push xabar yuborilsinmi.
  final bool notifyOnExit;

  /// Zona yaratilgan vaqt (server timestamp).
  final DateTime createdAt;

  /// Oxirgi yangilanish vaqti (server timestamp).
  final DateTime updatedAt;

  /// Material Icon nomi (`'home'`, `'school'`, va h.k.). UI'da ro'yxat
  /// va xaritada zona ikonkasi sifatida ishlatiladi. `null` bo'lsa
  /// `type.defaultIconName` ishlatiladi.
  final String? icon;

  /// Markaz `LatLng` obyekti (Google Maps Marker, Circle, CameraPosition
  /// uchun).
  LatLng get center => LatLng(latitude, longitude);

  /// Foydalanuvchi tanlashi mumkin bo'lgan ikonalar ro'yxati.
  /// `AddEditGeoZoneScreen`'dagi icon picker shu ro'yxatdan generatsiya
  /// qiladi.
  static const List<String> availableIcons = [
    'home',
    'school',
    'place',
    'park',
    'sports',
    'restaurant',
    'store',
    'work',
  ];

  /// String'dan `IconData`'ga konvertatsiya. Switch'da emas — kelajakda
  /// kengaytirish oson.
  static IconData iconFromString(String? name) {
    switch (name) {
      case 'home':
        return Icons.home;
      case 'school':
        return Icons.school;
      case 'park':
        return Icons.park;
      case 'sports':
        return Icons.sports_soccer;
      case 'restaurant':
        return Icons.restaurant;
      case 'store':
        return Icons.store;
      case 'work':
        return Icons.work;
      case 'place':
      default:
        return Icons.place;
    }
  }

  /// Yangi `GeoZone` yaratish — bitta yoki bir nechta maydonni
  /// o'zgartiradi. Riverpod state immutability uchun zarur.
  GeoZone copyWith({
    String? id,
    String? parentUid,
    String? childId,
    String? name,
    GeoZoneType? type,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? notifyOnEnter,
    bool? notifyOnExit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? icon,
  }) {
    return GeoZone(
      id: id ?? this.id,
      parentUid: parentUid ?? this.parentUid,
      childId: childId ?? this.childId,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      notifyOnEnter: notifyOnEnter ?? this.notifyOnEnter,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      icon: icon ?? this.icon,
    );
  }
}
