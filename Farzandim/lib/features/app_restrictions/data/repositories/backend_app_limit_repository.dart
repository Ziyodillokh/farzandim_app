// ─────────────────────────────────────────────────────────────────────
// BackendAppLimitRepository — Per-app limits (Backend 0.5.1)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (`/api/children/:childId/app-limits`):
//   GET    /api/children/:childId/app-limits → {limits: [...], count}
//   POST   /api/children/:childId/app-limits body: {packageName, dailyLimitMs}
//   PUT    /api/app-limits/:id body: {dailyLimitMs}
//   DELETE /api/app-limits/:id
//
// Mapping:
//   Block       → POST { packageName, dailyLimitMs: 0 }
//   Limit 30min → POST { packageName, dailyLimitMs: 1800000 }
//   Remove      → DELETE /app-limits/:id

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAppLimitRepositoryProvider =
    Provider<BackendAppLimitRepository>((ref) {
  return BackendAppLimitRepository(dio: ref.watch(dioClientProvider));
});

class BackendAppLimitRepository {
  BackendAppLimitRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bola uchun barcha app limit'lar — domain model.
  Future<List<AppRestriction>> getRestrictions(String childId) async {
    final wires = await _getLimits(childId);
    return wires.map((w) => w.toRestriction()).toList();
  }

  Future<List<_AppLimitWire>> _getLimits(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-limits',
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['limits'] as List<dynamic>? ?? const [];
      return list
          .map((m) => _AppLimitWire.fromJson(m as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendAppLimitRepository._getLimits: $e');
      return const [];
    }
  }

  /// Upsert: agar `packageName` uchun limit mavjud bo'lsa PUT,
  /// aks holda POST. Backend `(childId, packageName)` unique
  /// bo'lishi taxmin qilinadi.
  Future<bool> upsert({
    required String childId,
    required String packageName,
    required String appName,
    required int dailyLimitMs,
  }) async {
    try {
      final existing = await _getLimits(childId);
      final match = existing
          .where((l) => l.packageName == packageName)
          .cast<_AppLimitWire?>()
          .firstWhere((_) => true, orElse: () => null);
      if (match != null) {
        await _dio.put<void>(
          '/app-limits/${match.id}',
          data: {'dailyLimitMs': dailyLimitMs},
        );
      } else {
        await _dio.post<void>(
          '/children/$childId/app-limits',
          data: {
            'packageName': packageName,
            'appName': appName,
            'dailyLimitMs': dailyLimitMs,
          },
        );
      }
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendAppLimitRepository.upsert xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      rethrow;
    }
  }

  /// Cheklovni o'chirish.
  ///
  /// **Eslatma:** Fastify 5 JSON parser DELETE bo'sh body bilan
  /// `FST_ERR_CTP_INVALID_JSON_BODY` 400 qaytaradi. Bo'sh `{}` yuboramiz
  /// (worth: markAsRead pattern bilan bir xil).
  Future<bool> remove({
    required String childId,
    required String packageName,
  }) async {
    try {
      final existing = await _getLimits(childId);
      final match = existing
          .where((l) => l.packageName == packageName)
          .cast<_AppLimitWire?>()
          .firstWhere((_) => true, orElse: () => null);
      if (match == null) return true; // already absent
      await _dio.delete<void>(
        '/app-limits/${match.id}',
        data: <String, dynamic>{},
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendAppLimitRepository.remove xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      return false;
    }
  }
}

@immutable
class _AppLimitWire {
  const _AppLimitWire({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.dailyLimitMs,
    required this.updatedAt,
  });

  factory _AppLimitWire.fromJson(Map<String, dynamic> json) {
    return _AppLimitWire(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      appName: (json['appName'] as String?) ?? '',
      dailyLimitMs: (json['dailyLimitMs'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  final String id;
  final String packageName;
  final String appName;
  final int dailyLimitMs;
  final DateTime updatedAt;

  /// Domain modelga konvertatsiya.
  AppRestriction toRestriction() {
    return AppRestriction(
      packageName: packageName,
      appName: appName,
      limitMinutes: dailyLimitMs ~/ 60000,
      isBlocked: dailyLimitMs == 0,
      updatedAt: updatedAt,
    );
  }
}

