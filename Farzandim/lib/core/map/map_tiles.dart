// ─────────────────────────────────────────────────────────────────────
// Xarita plitkalari — BITTA joyda boshqariladi (barcha xarita ekranlari
// shu yerdan oladi: joylashuv, geo-zona, tarix, SOS).
// ─────────────────────────────────────────────────────────────────────
//
// Standart: Mapbox **light-v11** (OQ/kulrang, ko'chalar aniq — Yandex Go
// uslubi, retina @2x bilan tiniq). Mapbox token yo'q bo'lsa — CARTO **light**
// (kalitsiz, OQ). Har ikkisi ham OQ fon beradi, shuning uchun xarita hech
// qачон "qora"ga tushmaydi.
//
// Token: `ApiKeys.mapboxPublicToken` (runtime assets/env.json ustun, keyin
// compile-time --dart-define). Public `pk.…` token URL ичida bo'ladi — bu
// Mapbox uchun normal (public token, URL-cheklovi bilan himoyalanadi).

import 'package:farzandim/core/constants/api_keys.dart';

/// Mapbox uslubi — `light-v11`: oq/kulrang fon, ko'chalar aniq o'qiladi.
const String _mapboxLightStyle = 'mapbox/light-v11';

/// CARTO light (kalitsiz zaxira) — Mapbox token bo'lmasa. OQ fon, OSM data.
/// Prod attribution: © OpenStreetMap contributors, © CARTO.
const String _cartoLightUrl =
    'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

/// Xarita paketi nomi (User-Agent) — plitka serverlari talab qilishi mumkin.
const String kMapUserAgent = 'uz.farzandim.app';

/// OQ xarita plitka URL shabloni (flutter_map `TileLayer.urlTemplate`).
///
/// Mapbox token bor → Mapbox `light-v11` (retina @2x, aniq ko'chalar).
/// Token yo'q → CARTO light (kalitsiz). Har ikkisi OQ fon.
String get whiteMapTileUrl {
  final token = ApiKeys.mapboxPublicToken;
  if (token.isEmpty) return _cartoLightUrl;
  return 'https://api.mapbox.com/styles/v1/$_mapboxLightStyle'
      '/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
}

/// Plitkalar Mapbox'danmi (attribution matni to'g'ri chiqishi uchun).
bool get isMapboxTiles => ApiKeys.mapboxPublicToken.isNotEmpty;

/// Xarita pastida ko'rsatiladigan attribution matni (ToS talabi).
String get mapAttribution => isMapboxTiles
    ? '© Mapbox © OpenStreetMap'
    : '© OpenStreetMap © CARTO';
