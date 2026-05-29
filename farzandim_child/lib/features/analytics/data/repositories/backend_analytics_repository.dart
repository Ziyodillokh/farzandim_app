// ─────────────────────────────────────────────────────────────────────
// BackendAnalyticsRepository — Child App read-only (Sprint 4.4.32)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/children/:childId/installed-apps?includeSystem=
//   GET /api/children/:childId/app-usage?from=&to=&packageName=&limit=
//
// Response (usage): {
//   usages: [{ packageName, date, foregroundMs, openCount, lastUsedAt }]
// }
// Response (installed): {
//   apps: [{ packageName, appName, iconBase64?, iconUrl?, lastSeenAt }]
// }

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/analytics/data/models/app_usage_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAnalyticsRepositoryProvider =
    Provider<BackendAnalyticsRepository>((ref) {
  return BackendAnalyticsRepository(dio: ref.watch(dioClientProvider));
});

class BackendAnalyticsRepository {
  BackendAnalyticsRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Installed apps map (packageName → meta). Public — UI'da AppLimit
  /// uchun nom va icon olishda kerak.
  Future<Map<String, InstalledAppMeta>> getInstalledApps(
    String childId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/installed-apps',
        queryParameters: {'includeSystem': false},
      );
      final list =
          response.data?['apps'] as List<dynamic>? ?? const <dynamic>[];
      final map = <String, InstalledAppMeta>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final pkg = m['packageName'] as String?;
        if (pkg == null) continue;
        map[pkg] = InstalledAppMeta(
          appName: m['appName'] as String? ?? pkg,
          iconBase64: m['iconBase64'] as String?,
          iconUrl: m['iconUrl'] as String?,
        );
      }
      return map;
    } on DioException catch (e) {
      debugPrint('BackendAnalytics.getInstalledApps: $e');
      return const {};
    }
  }

  /// `date` (YYYY-MM-DD) uchun bola usage.
  /// installed-apps merge bilan appName + icon to'liq.
  Future<AppUsageDay> getUsageByDate({
    required String childId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-usage',
        queryParameters: {'from': dateStr, 'to': dateStr, 'limit': 500},
      );
      final entries =
          response.data?['usage'] as List<dynamic>? ?? const <dynamic>[];
      final installed = await getInstalledApps(childId);
      final apps = entries.map((m) {
        final json = m as Map<String, dynamic>;
        final pkg = json['packageName'] as String? ?? '';
        final installedInfo = installed[pkg];
        return AppUsageEntry.fromMap({
          'packageName': pkg,
          'appName': installedInfo?.appName ?? pkg,
          'totalTimeMs': (json['foregroundMs'] as num?)?.toInt() ?? 0,
          'lastTimeUsed': json['lastUsedAt'],
          'iconBase64': installedInfo?.iconBase64,
          'iconUrl': installedInfo?.iconUrl,
        });
      }).toList()
        ..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs));
      return AppUsageDay(date: dateStr, apps: apps);
    } on DioException catch (e) {
      debugPrint('BackendAnalytics.getUsageByDate: $e');
      return AppUsageDay(date: dateStr, apps: const []);
    }
  }

  /// `endDate`'dan 6 kun oldingi `from` bilan haftalik aggregate.
  /// Returns: List<{ date, totalMs }> — eski kun avval, oxirgi kun oxirida.
  Future<List<DailyUsageTotal>> getWeeklyTotals({
    required String childId,
    required DateTime endDate,
  }) async {
    final start = endDate.subtract(const Duration(days: 6));
    final fromStr = _formatDate(start);
    final toStr = _formatDate(endDate);
    try {
      // Backend max limit = 1000. 7 kun × ~30 app = ~210 entry — yetarli.
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-usage',
        queryParameters: {'from': fromStr, 'to': toStr, 'limit': 1000},
      );
      final entries =
          response.data?['usage'] as List<dynamic>? ?? const <dynamic>[];

      // Date → totalMs aggregate.
      final totals = <String, int>{};
      for (final m in entries) {
        final json = m as Map<String, dynamic>;
        final dateRaw = json['date'] as String?;
        if (dateRaw == null) continue;
        final ms = (json['foregroundMs'] as num?)?.toInt() ?? 0;
        totals[dateRaw] = (totals[dateRaw] ?? 0) + ms;
      }

      // 7 kun ro'yxati (bo'sh kunlar 0 bilan).
      final result = <DailyUsageTotal>[];
      for (var i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        final key = _formatDate(day);
        result.add(DailyUsageTotal(date: day, totalMs: totals[key] ?? 0));
      }
      return result;
    } on DioException catch (e) {
      debugPrint('BackendAnalytics.getWeeklyTotals: $e');
      // Fallback: 7 ta bo'sh kun.
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
}

class InstalledAppMeta {
  const InstalledAppMeta({
    required this.appName,
    this.iconBase64,
    this.iconUrl,
  });
  final String appName;
  final String? iconBase64;
  final String? iconUrl;
}

@immutable
class DailyUsageTotal {
  const DailyUsageTotal({required this.date, required this.totalMs});
  final DateTime date;
  final int totalMs;

  double get hours => totalMs / 3600000;
}
