// ─────────────────────────────────────────────────────────────────────
// SchoolModeMeta — maktab School Mode jadvalining qurilma uchun tafsiloti
// ─────────────────────────────────────────────────────────────────────
//
// Server virtual "Maktab" jadvaliga `schoolMode` qo'shadi:
//   - blockedCategories — dars vaqtida bloklanadigan toifalar (GAME / SOCIAL /
//     VIDEO). Server ro'yxatiga hali tushmagan yangi o'yin ham qurilma
//     toifasi bo'yicha darhol bloklanadi;
//   - allowedApps — maktab ruxsat bergan ilovalar nomi;
//   - zone — «faqat maktab hududida»: telefon hududda ekanini qurilmaning o'zi
//     aniqlaydi (joylashuv bu maqsadda serverga yuborilmaydi). `null` —
//     butun dars vaqti, joylashuvdan qat'i nazar.

import 'package:flutter/foundation.dart';

@immutable
class SchoolZone {
  const SchoolZone({
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  /// Noto'g'ri yoki to'liq bo'lmagan qiymat — `null` (hudud yo'q deb).
  static SchoolZone? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['latitude'];
    final lng = json['longitude'];
    final radius = json['radiusM'];
    if (lat is! num || lng is! num || radius is! num || radius <= 0) {
      return null;
    }
    return SchoolZone(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      radiusM: radius.toInt(),
    );
  }

  final double latitude;
  final double longitude;
  final int radiusM;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radiusM': radiusM,
  };
}

@immutable
class SchoolModeMeta {
  const SchoolModeMeta({
    this.blockedCategories = const [],
    this.allowedApps = const [],
    this.zone,
  });

  factory SchoolModeMeta.fromJson(Map<String, dynamic> json) => SchoolModeMeta(
    blockedCategories: _strings(json['blockedCategories']),
    allowedApps: _strings(json['allowedApps']),
    zone: SchoolZone.tryFromJson(json['zone']),
  );

  final List<String> blockedCategories;
  final List<String> allowedApps;
  final SchoolZone? zone;

  Map<String, dynamic> toJson() => {
    'blockedCategories': blockedCategories,
    'allowedApps': allowedApps,
    'zone': zone?.toJson(),
  };

  static List<String> _strings(Object? raw) => raw is List
      ? raw.map((e) => '$e').where((e) => e.isNotEmpty).toList(growable: false)
      : const [];
}
