// ─────────────────────────────────────────────────────────────────────
// BackendAppLimitRepository — Per-app limits (Sprint 4.4.25)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (`GET /api/children/:childId/app-limits`):
//   Response 200: { limits: [{ id, packageName, dailyLimitMs,
//                              weeklyLimitMs?, isActive, ... }], count }
//
// Child App faqat **read-only** — POST/PUT/DELETE Parent App tomonidan.
// `RestrictionsSyncService` har 5 daq + WS `app_limit:*` event paytida
// chaqiradi va SharedPreferences orqali native plugin'ga yetkazadi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAppLimitRepositoryProvider =
    Provider<BackendAppLimitRepository>((ref) {
  return BackendAppLimitRepository(dio: ref.watch(dioClientProvider));
});

class BackendAppLimitRepository {
  BackendAppLimitRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bola uchun barcha aktiv per-package limit'lar.
  ///
  /// `dailyLimitMs == 0` — to'liq block (limitsiz block)
  /// `dailyLimitMs > 0`  — kunlik vaqt cheklovi
  ///
  /// XAVFSIZLIK (fail-closed): tarmoq xatosida `null` qaytadi — bu "BILMAYMAN"
  /// degani, "ota-ona hech narsa bloklamagan" EMAS. Avval bo'sh ro'yxat
  /// qaytardi va `RestrictionsSyncService` uni "limit yo'q" deb tushunib
  /// SharedPreferences'ni TOZALARDI → bola internetni o'chirsa ~15 soniyada
  /// BARCHA bloklar o'chib ketardi (aviarejim = to'liq bypass). Endi `null`
  /// bo'lsa sync prefs'ga umuman tegmaydi va oxirgi ma'lum bloklar kuchda
  /// qoladi.
  Future<List<AppLimit>?> getLimits(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-limits',
        queryParameters: {'isActive': 'true'},
      );
      final data = response.data;
      if (data == null) return null;
      final list = data['limits'] as List<dynamic>? ?? const [];
      return list
          .map((m) => AppLimit.fromJson(m as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint(
        'BackendAppLimitRepository.getLimits xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      return null;
    }
  }
}

@immutable
class AppLimit {
  const AppLimit({
    required this.id,
    required this.packageName,
    required this.dailyLimitMs,
    this.weeklyLimitMs,
    this.isActive = true,
  });

  factory AppLimit.fromJson(Map<String, dynamic> json) {
    return AppLimit(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      dailyLimitMs: (json['dailyLimitMs'] as num?)?.toInt() ?? 0,
      weeklyLimitMs: (json['weeklyLimitMs'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String packageName;
  final int dailyLimitMs;
  final int? weeklyLimitMs;
  final bool isActive;

  /// `true` agar to'liq block (kunlik 0 ms ruxsat).
  bool get isFullBlock => dailyLimitMs == 0;

  /// Kunlik limit daqiqalarda (native plugin formati uchun).
  int get dailyLimitMinutes => dailyLimitMs ~/ 60000;
}
