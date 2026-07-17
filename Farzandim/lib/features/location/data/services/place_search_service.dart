// ─────────────────────────────────────────────────────────────────────
// PlaceSearchService — manzil/joy QIDIRUV (forward geocoding, autocomplete).
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanuvchi "masjid", "22-maktab", ko'cha nomi yozadi → mos joylar.
// Manba: **Photon** (photon.komoot.io) — OpenStreetMap ustiga qurilган BEPUL,
// KALITSIZ, aynan as-you-type qidiruv uchun mo'ljallangan geokoder. Kategoriya
// (masjid/maktab) + manzil + nomli joylarni qaytaradi. Toshkent qamrovi yaxshi.
//
// Natijalar berilган MARKAZ (xarita markazi)ga BIAS qilinadi (yaqinlari ustun),
// so'ng mijoz tomonда haversine bilan ENG YAQINDAN uzoqqa saralanadi.
//
// Nega Yandex emas: bepul Yandex Geocoder kategoriya (masjid) qaytarmaydi
// (faqat manzil/toponim); Yandex Places pullik. OSM/Photon bepul + kategoriya.
// Prod eslatma: jamoat Photon serveri katta yuklamada cheklashi mumkin —
// keyinchalik self-host yoki pullik provayderga o'tish mumkin.

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) {
  return PlaceSearchService();
});

/// Qidiruvni ishga tushirishдан oldingi minimal belgilar soni.
const int kMinSearchChars = 2;

/// Joy kategoriyasi — UI'да mos ikon tanlash uchun (osm_key/osm_value'дан
/// hosil qilinadi). Bilinmasa `other`.
enum PlaceKind {
  school,
  mosque,
  park,
  hospital,
  shop,
  restaurant,
  street,
  city,
  other,
}

/// Qidiruv natijasi — bitta joy taxmini.
@immutable
class PlaceSuggestion {
  /// `PlaceSuggestion` konstruktor.
  const PlaceSuggestion({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.kind = PlaceKind.other,
  });

  /// Qisqa nom (masalan "Minor masjidi", "22-maktab", "Amir Temur ko'chasi").
  final String name;

  /// Kontekst manzil (masalan "Yunusobod tumani, Toshkent"). Bo'sh bo'lishi
  /// mumkin (nomli joyда qo'shimcha kontekst bo'lmasa).
  final String address;

  /// Koordinatalar.
  final double latitude;
  final double longitude;

  /// Markaz (xarita) dan masofa (metr) — saralash + UI masofa chipi uchun.
  final double distanceMeters;

  /// Kategoriya — UI ikonini tanlash uchun (masjid → gumbaz, maktab → daftar).
  final PlaceKind kind;
}

/// Photon (OSM) orqali joy qidiruv xizmati.
class PlaceSearchService {
  /// `PlaceSearchService` konstruktor (test uchun `dio` in'ektsiya).
  PlaceSearchService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint = 'https://photon.komoot.io/api/';

  /// [query] matnini [centerLat]/[centerLng] atrofida qidiradi va natijalarni
  /// ENG YAQINDAN uzoqqa saralab qaytaradi.
  ///
  /// [limit] — Photon'дан so'raladigan maksimal natija (default 20 — kamida
  /// 5 ta yaqin natija chiqishi uchun keng so'raymiz, so'ng saralaymiz).
  /// Query juda qisqa / tarmoq xatosi / natija yo'q → bo'sh ro'yxat.
  Future<List<PlaceSuggestion>> search({
    required String query,
    required double centerLat,
    required double centerLng,
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.length < kMinSearchChars) return const <PlaceSuggestion>[];

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: <String, dynamic>{
          'q': q,
          // Markazga bias (yaqin natijalar ustun bo'ladi).
          'lat': centerLat,
          'lon': centerLng,
          'limit': limit,
          // `lang` ataylab yuborilmaydi — Photon default (OSM mahalliy nomi,
          // o'zbek/rus) qaytaradi. Noto'g'ri lang'да ba'zi instance 400 beradi.
        },
        options: Options(
          // connectTimeout SHART — bo'lmasa flaky tarmoqда TCP ulanish
          // cheksiz osilib, receiveTimeout ishga tushmaydi (spinner qotadi).
          // sendTimeout GET (bodysiz) uchun no-op — qo'shilmadi.
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          // OSM/Photon odobi — haqiqiy User-Agent.
          headers: const <String, String>{
            'User-Agent': 'Farzandim/1.0 (parental control app)',
          },
        ),
      );

      final features = res.data?['features'];
      if (features is! List) return const <PlaceSuggestion>[];

      final out = <PlaceSuggestion>[];
      for (final raw in features) {
        if (raw is! Map) continue;

        // Har feature MUSTAQIL tekshiriladi (`as Map` cast o'rniga `is Map` —
        // bitta buzuq/noto'g'ri-tur feature butun ro'yxatni yiqitmasin).
        final geometry = raw['geometry'];
        if (geometry is! Map) continue;
        // geometry.coordinates = [LON, LAT] (GeoJSON — LONGITUDE oldinда!).
        final coords = geometry['coordinates'];
        if (coords is! List || coords.length < 2) continue;
        final lng = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final propsRaw = raw['properties'];
        final props = propsRaw is Map
            ? propsRaw
            : const <dynamic, dynamic>{};
        final name = _composeName(props);
        if (name.isEmpty) continue;

        out.add(
          PlaceSuggestion(
            name: name,
            address: _composeAddress(props),
            latitude: lat,
            longitude: lng,
            distanceMeters: _haversine(centerLat, centerLng, lat, lng),
            kind: _kindFromOsm(
              (props['osm_key'] as String?) ?? '',
              (props['osm_value'] as String?) ?? '',
            ),
          ),
        );
      }

      // Eng yaqindan uzoqqa (foydalanuvchi talabi).
      out.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return out;
    } catch (e) {
      debugPrint('PlaceSearchService.search xato: $e');
      return const <PlaceSuggestion>[];
    }
  }

  /// Ko'rsatiladigan nom: OSM `name` (masjid/maktab/joy nomi), bo'lmasa
  /// ko'cha (+ uy raqami), bo'lmasa shahar/kategoriya.
  static String _composeName(Map<dynamic, dynamic> p) {
    final name = (p['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;

    final street = (p['street'] as String?)?.trim();
    final houseNo = (p['housenumber'] as String?)?.trim();
    if (street != null && street.isNotEmpty) {
      return (houseNo != null && houseNo.isNotEmpty)
          ? '$street, $houseNo'
          : street;
    }
    final city = (p['city'] as String?)?.trim();
    return city ?? '';
  }

  /// Kontekst manzil: (nom bo'lsa) ko'cha, tuman, shahar, viloyat — takrorsiz.
  static String _composeAddress(Map<dynamic, dynamic> p) {
    final hasName = (p['name'] as String?)?.trim().isNotEmpty ?? false;
    final street = (p['street'] as String?)?.trim();
    final district = (p['district'] as String?)?.trim();
    final city = (p['city'] as String?)?.trim();
    final state = (p['state'] as String?)?.trim();

    final parts = <String>[
      // Nom bor bo'lsa ko'cha kontekstga qo'shiladi; aks holda ko'cha nomда.
      if (hasName && street != null && street.isNotEmpty) street,
      if (district != null && district.isNotEmpty) district,
      if (city != null && city.isNotEmpty && city != district) city,
    ];
    if (parts.isEmpty && state != null && state.isNotEmpty) parts.add(state);
    return parts.join(', ');
  }

  /// Ikki nuqta orasidagi masofa (metr) — haversine.
  static double _haversine(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  /// OSM `key/value` juftligидan foydalanuvchi ko'radigan kategoriya.
  /// Photon `osm_key='amenity'`, `osm_value='school'` va h.k. qaytaradi.
  static PlaceKind _kindFromOsm(String key, String value) {
    switch (value) {
      case 'school':
      case 'kindergarten':
      case 'university':
      case 'college':
        return PlaceKind.school;
      case 'place_of_worship':
      case 'mosque':
        return PlaceKind.mosque;
      case 'park':
      case 'garden':
      case 'playground':
        return PlaceKind.park;
      case 'hospital':
      case 'clinic':
      case 'pharmacy':
        return PlaceKind.hospital;
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return PlaceKind.restaurant;
    }
    switch (key) {
      case 'shop':
        return PlaceKind.shop;
      case 'highway':
        return PlaceKind.street;
      case 'place':
        return PlaceKind.city;
    }
    return PlaceKind.other;
  }
}
