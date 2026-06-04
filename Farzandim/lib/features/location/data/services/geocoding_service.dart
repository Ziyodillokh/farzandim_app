// ─────────────────────────────────────────────────────────────────────
// GeocodingService — koordinata → manzil (reverse geocoding)
// ─────────────────────────────────────────────────────────────────────
//
// Google Geocoding HTTP API ishlatadi (barcha platformalarda bir xil —
// mobil/web). `geocoding` paketi web'ni qo'llamaydi, shuning uchun HTTP.
// Kalit `ApiKeys.googleMapsKey` (env.json). Natija keshlanadi (bir xil
// koordinatani qayta so'ramaslik uchun). Kalit yo'q / API o'chiq / tarmoq
// xatosi bo'lsa `null` qaytadi — UI koordinata yoki "Noma'lum" ko'rsatadi.
//
// Eslatma: kalit Google Cloud'da "Geocoding API" yoqilgan bo'lishi kerak
// (Maps SDK bilan bir xil loyihada, bir tugma).

import 'package:dio/dio.dart';
import 'package:farzandim/core/constants/api_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

class GeocodingService {
  GeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, String?> _cache = <String, String?>{};

  /// Koordinatani qisqa manzilga aylantiradi (masalan "Bobur ko'chasi,
  /// Andijon"). Keshlanadi. Xato bo'lsa `null`.
  Future<String?> reverse(
    double latitude,
    double longitude, {
    String language = 'uz',
  }) async {
    // ~11 m aniqlik (4 kasr) — kesh kaliti.
    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final apiKey = ApiKeys.googleMapsKey;
    if (apiKey.isEmpty) {
      _cache[cacheKey] = null;
      return null;
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: <String, dynamic>{
          'latlng': '$latitude,$longitude',
          'language': language,
          'key': apiKey,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      final data = res.data;
      final status = data?['status'] as String?;
      final results = data?['results'] as List<dynamic>?;
      if (status != 'OK' || results == null || results.isEmpty) {
        if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
          debugPrint('GeocodingService: status=$status (kalit/API tekshiring)');
        }
        _cache[cacheKey] = null;
        return null;
      }
      final formatted =
          (results.first as Map<String, dynamic>)['formatted_address']
              as String?;
      final short = _shorten(formatted);
      _cache[cacheKey] = short;
      return short;
    } catch (e) {
      debugPrint('GeocodingService.reverse xato: $e');
      _cache[cacheKey] = null;
      return null;
    }
  }

  /// To'liq manzildan birinchi 2 qismni oladi: "Ko'cha, Shahar".
  String? _shorten(String? full) {
    if (full == null || full.trim().isEmpty) return null;
    final parts = full
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length <= 2) return full.trim();
    return parts.take(2).join(', ');
  }
}
