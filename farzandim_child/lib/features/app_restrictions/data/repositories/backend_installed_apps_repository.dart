// ─────────────────────────────────────────────────────────────────────
// BackendInstalledAppsRepository — Installed apps + App usage batch
// (Sprint 4.4.10)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST /api/children/:childId/installed-apps body: {apps: [...]}
//   GET  /api/children/:childId/installed-apps?includeSystem=true
//   POST /api/children/:childId/app-usage body: {entries: [...]}
//   GET  /api/children/:childId/app-usage?from=&to=&packageName=&limit=
//
// Upsert keys:
//   installed-apps: (childId, packageName) — har upsert lastSeenAt
//   app-usage: (childId, packageName, date) — kunlik aggregat

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendInstalledAppsRepositoryProvider =
    Provider<BackendInstalledAppsRepository>((ref) {
  return BackendInstalledAppsRepository(dio: ref.watch(dioClientProvider));
});

class BackendInstalledAppsRepository {
  BackendInstalledAppsRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Batch upsert installed apps. Backend `(childId, packageName)`
  /// unique key bo'yicha upsert qiladi, `lastSeenAt` har upsert
  /// avtomatik yangilanadi.
  ///
  /// `apps` ro'yxati elementi:
  /// - `packageName` (majburiy)
  /// - `appName` (majburiy)
  /// - `versionName`, `versionCode`, `installSource`, `iconPath`,
  ///   `isSystem` (ixtiyoriy)
  Future<bool> upsertInstalledApps({
    required String childId,
    required List<Map<String, dynamic>> apps,
  }) async {
    if (apps.isEmpty) return true;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/children/$childId/installed-apps',
        data: {'apps': apps},
      );
      debugPrint(
        'BackendInstalledApps: ${apps.length} ta app upsert qilindi',
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendInstalledAppsRepository.upsertInstalledApps xato '
        '${e.response?.statusCode}',
      );
      return false;
    }
  }

  /// Batch upsert app usage statistics. Backend
  /// `(childId, packageName, date)` unique key bilan upsert.
  ///
  /// `entries` ro'yxati elementi:
  /// - `packageName`, `date` (`"YYYY-MM-DD"`), `foregroundMs`,
  ///   `openCount`, `lastUsedAt` (ISO 8601)
  Future<bool> upsertAppUsage({
    required String childId,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.isEmpty) return true;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/children/$childId/app-usage',
        data: {'entries': entries},
      );
      debugPrint(
        'BackendAppUsage: ${entries.length} ta entry upsert qilindi',
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendInstalledAppsRepository.upsertAppUsage xato '
        '${e.response?.statusCode}',
      );
      return false;
    }
  }

  /// Kunlik qadam sonini yuboradi (Parvoz pedometer).
  /// Backend `(childId, date)` unique key bilan upsert.
  /// `entries` elementi: `date` (`"YYYY-MM-DD"`), `steps` (int).
  Future<bool> upsertSteps({
    required String childId,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.isEmpty) return true;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/children/$childId/steps',
        data: {'entries': entries},
      );
      debugPrint('BackendSteps: ${entries.length} ta entry upsert qilindi');
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendInstalledAppsRepository.upsertSteps xato '
        '${e.response?.statusCode}',
      );
      return false;
    }
  }
}
