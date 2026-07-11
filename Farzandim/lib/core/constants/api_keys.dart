// API kalitlari: assets/env.json'dan (git'da yo'q) runtime'da yuklanadi;
// --dart-define compile-time fallback ham ishlaydi, runtime asset ustun.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// API kalitlari — runtime'da `init()` chaqirilib to'ldiriladi.
class ApiKeys {
  ApiKeys._();

  static String _googleMapsKey = const String.fromEnvironment('MAPS_API_KEY');

  static String _mapboxPublicToken = const String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
  );

  static String _yandexMapsKey = const String.fromEnvironment(
    'YANDEX_MAPS_KEY',
  );

  /// Google Maps + Places API kaliti.
  static String get googleMapsKey => _googleMapsKey;

  /// Yandex Maps API kaliti — Geocoder (manzil qidiruv + koordinata→ko'cha).
  /// Runtime `assets/env.json` ustun; bo'lmasa compile-time (`--dart-define`).
  /// Placeholder (`BU_YERGA...`) yoki bo'sh → '' → qidiruv jimgina o'chiq.
  static String get yandexMapsKey =>
      _isRealKey(_yandexMapsKey) ? _yandexMapsKey : '';

  /// Kalit haqiqiymi — bo'sh emas va placeholder marker (`BU_YERGA`/`YOUR`)
  /// tutmaydi (aks holda API 403 → jim ishlamaslik o'rniga o'chirамiz).
  static bool _isRealKey(String k) =>
      k.isNotEmpty && !k.contains('BU_YERGA') && !k.contains('YOUR');

  /// Mapbox public token (`pk.…`) — OQ xarita render (raster plitka).
  /// Runtime `assets/env.json` ustun; bo'lmasa compile-time (`--dart-define`);
  /// u ham bo'lmasa bo'sh → xarita CARTO light (kalitsiz, oq) ga tushadi.
  ///
  /// Faqat HAQIQIY token qaytadi: Mapbox pk tokenlari JWT — `pk.eyJ` bilan
  /// boshlanadi. Placeholder (`pk.BU_YERGA...`) `pk.eyJ` emas → bo'sh
  /// qaytadi → 401/buzuq plitka o'rniga CARTO oq fallback ishlaydi.
  static String get mapboxPublicToken =>
      _mapboxPublicToken.startsWith('pk.eyJ') ? _mapboxPublicToken : '';

  /// Startup'da chaqiriladi (`main.dart`'dan). `assets/env.json` topilsa
  /// runtime'dan keladi; topilmasa compile-time fallback'da qoladi.
  static Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/env.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final mapsKey = (map['MAPS_API_KEY'] as String?) ?? '';
      if (mapsKey.isNotEmpty && !mapsKey.contains('YOUR_')) {
        _googleMapsKey = mapsKey;
      }
      // Mapbox pk token — faqat haqiqiy JWT (`pk.eyJ…`) qabul qilinadi
      // (placeholder `pk.BU_YERGA` o'tkazilmaydi, aks holda 401 → oq ekran).
      final mapbox = (map['MAPBOX_PUBLIC_TOKEN'] as String?) ?? '';
      if (mapbox.startsWith('pk.eyJ')) {
        _mapboxPublicToken = mapbox;
      }
      final yandex = (map['YANDEX_MAPS_KEY'] as String?) ?? '';
      if (_isRealKey(yandex)) {
        _yandexMapsKey = yandex;
      }
      debugPrint('ApiKeys: runtime env.json loaded');
    } catch (e) {
      debugPrint('ApiKeys: env.json not found in assets — using flag fallback');
    }
  }
}
