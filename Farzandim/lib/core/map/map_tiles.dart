// ─────────────────────────────────────────────────────────────────────
// Xarita plitkalari — BITTA joyda boshqariladi (barcha xarita ekranlari
// shu yerdan oladi: joylashuv, geo-zona, tarix, SOS).
// ─────────────────────────────────────────────────────────────────────
//
// Standart: Mapbox **streets-v12** — YORUG' fon + BOY tafsilot (POI ikonlari:
// masjid, maktab, do'kon, park... — Google Maps uslubi). Mapbox token yo'q
// bo'lsa OpenStreetMap standart plitkalari (kalitsiz). CARTO voyager
// ishlatilmaydi: 2026-11 dan kalitsiz so'rovga «API KEY REQUIRED» plitkasini
// qaytaradi — token yo'q APK'da xarita o'rnida shu yozuv chiqardi.
//
// (Ilgari light-v11/light_all ishlatilardi — juda minimal, faqat matn edi;
// foydalanuvchi "Google/Yandex kabi ikonlar bilan" so'radi → boyroq uslub.)
//
// Token: `ApiKeys.mapboxPublicToken` (runtime assets/env.json ustun, keyin
// compile-time --dart-define). Public `pk.…` token URL ичida bo'ladi — bu
// Mapbox uchun normal (public token, URL-cheklovi bilan himoyalanadi).

import 'package:farzandim/core/constants/api_keys.dart';

/// Mapbox uslubi — `streets-v12`: yorug' fon, ko'chalar + POI ikonlari boy.
const String _mapboxStyle = 'mapbox/streets-v12';

/// OpenStreetMap (kalitsiz zaxira) — Mapbox token bo'lmasa. OSM tile usage
/// policy: aniq User-Agent ([kMapUserAgent]) va attribution shart.
const String _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Xarita paketi nomi (User-Agent) — plitka serverlari talab qilishi mumkin.
const String kMapUserAgent = 'uz.farzandim.app';

/// Xarita plitka URL shabloni (flutter_map `TileLayer.urlTemplate`).
///
/// Mapbox token bor → Mapbox `streets-v12` (retina @2x, boy POI). Token yo'q →
/// OpenStreetMap (kalitsiz). Har ikkisi yorug' fon + ikonlar.
String get mapTileUrl {
  final token = ApiKeys.mapboxPublicToken;
  if (token.isEmpty) return _osmUrl;
  return 'https://api.mapbox.com/styles/v1/$_mapboxStyle'
      '/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
}

/// Plitkalar Mapbox'danmi (attribution matni + retina rejimi uchun).
bool get isMapboxTiles => ApiKeys.mapboxPublicToken.isNotEmpty;

/// Xarita pastida ko'rsatiladigan attribution matni (ToS talabi).
String get mapAttribution =>
    isMapboxTiles ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap contributors';
