// ─────────────────────────────────────────────────────────────────────
// BackendAppUsageRepository — Parent read-only (Sprint 4.4.23)
// ─────────────────────────────────────────────────────────────────────
//
// Child App'da yozadigan `BackendInstalledAppsRepository` bilan parallel.
// Backend endpoint'lar:
//   GET /api/children/:childId/installed-apps?includeSystem=true
//   GET /api/children/:childId/app-usage?from=&to=&packageName=&limit=

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAppUsageRepositoryProvider =
    Provider<BackendAppUsageRepository>((ref) {
  return BackendAppUsageRepository(dio: ref.watch(dioClientProvider));
});

class BackendAppUsageRepository {
  BackendAppUsageRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bola qurilmasidagi o'rnatilgan ilovalar ro'yxati.
  Future<List<AppUsageEntry>> getInstalledApps({
    required String childId,
    bool includeSystem = false,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/installed-apps',
        queryParameters: {'includeSystem': includeSystem},
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['apps'] as List<dynamic>? ?? const [];
      return list
          .map((m) => AppUsageEntry.fromMap({
                'packageName': (m as Map)['packageName'],
                'appName': m['appName'],
                'totalTimeMs': 0,
                'lastTimeUsed': m['lastSeenAt'],
                'iconBase64': m['iconBase64'],
                // Backend MinIO signed URL (Sprint 4.4.29).
                'iconUrl': m['iconUrl'],
              }))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendAppUsageRepository.getInstalledApps: $e');
      return const [];
    }
  }

  /// Sprint 5.x — 7 kunlik kunlik totals (Parent dashboard ScreenTimeChart uchun).
  /// `endDate`'dan 6 kun oldingi `from` bilan haftalik aggregate.
  Future<List<DailyUsageTotal>> getWeeklyTotals({
    required String childId,
    required DateTime endDate,
  }) async {
    final start = endDate.subtract(const Duration(days: 6));
    final fromStr = _formatDate(start);
    final toStr = _formatDate(endDate);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-usage',
        queryParameters: {'from': fromStr, 'to': toStr, 'limit': 1000},
      );
      final entries =
          response.data?['usage'] as List<dynamic>? ?? const <dynamic>[];

      // Backend `date`'ni ISO datetime sifatida qaytaradi (Prisma DateTime →
      // "2026-05-19T00:00:00.000Z"). Kalit "YYYY-MM-DD" bo'lishi shart —
      // shuning uchun har bir entry'ni parse qilib local key'ga aylantiramiz.
      final totals = <String, int>{};
      for (final m in entries) {
        final json = m as Map<String, dynamic>;
        final dateRaw = json['date'] as String?;
        if (dateRaw == null) continue;
        final parsed = DateTime.tryParse(dateRaw);
        if (parsed == null) continue;
        final key = _formatDate(parsed.toLocal());
        final ms = (json['foregroundMs'] as num?)?.toInt() ?? 0;
        totals[key] = (totals[key] ?? 0) + ms;
      }

      final result = <DailyUsageTotal>[];
      for (var i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        final key = _formatDate(day);
        result.add(DailyUsageTotal(date: day, totalMs: totals[key] ?? 0));
      }
      return result;
    } on DioException catch (e) {
      debugPrint('BackendAppUsageRepository.getWeeklyTotals: $e');
      final start = endDate.subtract(const Duration(days: 6));
      return List.generate(
        7,
        (i) => DailyUsageTotal(
          date: start.add(Duration(days: i)),
          totalMs: 0,
        ),
      );
    }
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Bola uchun bugungi `AppUsageDay` aggregat.
  Future<AppUsageDay?> getTodayUsage(String childId) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-usage',
        queryParameters: {'from': dateStr, 'to': dateStr, 'limit': 500},
      );
      final data = response.data;
      if (data == null) return null;
      final entries = data['usage'] as List<dynamic>? ?? const [];
      if (entries.isEmpty) return null;
      final apps = entries
          .map((m) => AppUsageEntry.fromMap({
                'packageName': (m as Map)['packageName'],
                'appName': m['packageName'], // appName Backend'da yo'q
                'totalTimeMs': (m['foregroundMs'] as num?)?.toInt() ?? 0,
                'lastTimeUsed': m['lastUsedAt'],
              }))
          .toList();
      return AppUsageDay(
        date: dateStr,
        updatedAt: DateTime.now(),
        apps: apps,
      );
    } on DioException catch (e) {
      debugPrint('BackendAppUsageRepository.getTodayUsage: $e');
      return null;
    }
  }
}

/// Sprint 5.x — Parent dashboard ScreenTimeChart uchun kunlik aggregat.
class DailyUsageTotal {
  const DailyUsageTotal({required this.date, required this.totalMs});
  final DateTime date;
  final int totalMs;

  double get hours => totalMs / 3600000;
}
