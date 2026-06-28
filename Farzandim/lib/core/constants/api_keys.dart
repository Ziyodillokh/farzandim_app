// API kalitlari: assets/env.json'dan (git'da yo'q) runtime'da yuklanadi;
// --dart-define compile-time fallback ham ishlaydi, runtime asset ustun.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// API kalitlari — runtime'da `init()` chaqirilib to'ldiriladi.
class ApiKeys {
  ApiKeys._();

  static String _googleMapsKey = const String.fromEnvironment('MAPS_API_KEY');

  /// Google Maps + Places API kaliti.
  static String get googleMapsKey => _googleMapsKey;

  /// Startup'da chaqiriladi (`main.dart`'dan). `assets/env.json` topilsa
  /// runtime'dan keladi; topilmasa compile-time fallback'da qoladi.
  static Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/env.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final mapsKey = (map['MAPS_API_KEY'] as String?) ?? '';
      if (mapsKey.isNotEmpty && !mapsKey.contains('YOUR_')) {
        _googleMapsKey = mapsKey;
        debugPrint('ApiKeys: runtime env.json loaded');
      }
    } catch (e) {
      debugPrint('ApiKeys: env.json not found in assets — using flag fallback');
    }
  }
}
