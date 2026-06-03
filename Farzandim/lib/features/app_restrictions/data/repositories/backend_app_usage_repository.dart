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
      return list.map((m) {
        final map = m as Map;
        final pkg = '${map['packageName']}';
        // Backend signed MinIO URL telefon uchun yetib bo'lmaydi
        // (MINIO_PUBLIC_URL ichki manzil). Backend ikona bor deb belgilasa
        // (iconUrl != null), barqaror proxy URL quramiz — backend rasmni
        // o'zi stream qiladi (`/installed-apps/:pkg/icon`).
        final hasIcon = map['iconUrl'] != null || map['iconPath'] != null;
        final iconUrl = hasIcon ? _iconProxyUrl(childId, pkg) : null;
        return AppUsageEntry.fromMap({
          'packageName': pkg,
          'appName': map['appName'],
          'totalTimeMs': 0,
          'lastTimeUsed': map['lastSeenAt'],
          'iconBase64': map['iconBase64'],
          'iconUrl': iconUrl,
        });
      }).toList();
    } on DioException catch (e) {
      debugPrint('BackendAppUsageRepository.getInstalledApps: $e');
      return const [];
    }
  }

  /// Ilova ikonasi proxy URL — backend MinIO'dan rasmni stream qiladi.
  String _iconProxyUrl(String childId, String packageName) =>
      '${_dio.options.baseUrl}/children/$childId/installed-apps/'
      '${Uri.encodeComponent(packageName)}/icon';

  /// 7 kunlik kunlik totals — backend `/weekly` (system filtrlangan + UTC+5).
  /// `endDate` faqat xato holatidagi fallback uchun (server o'zi hisoblaydi).
  Future<List<DailyUsageTotal>> getWeeklyTotals({
    required String childId,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-usage/weekly',
      );
      final days = response.data?['days'] as List<dynamic>? ?? const [];
      return days.map((d) {
        final m = d as Map;
        final date =
            DateTime.tryParse('${m['date']}') ?? DateTime.now();
        return DailyUsageTotal(
          date: date,
          totalMs: (m['totalMs'] as num?)?.toInt() ?? 0,
        );
      }).toList();
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

  /// Toshkent (UTC+5) bugungi sanasi "YYYY-MM-DD".
  static String tashkentTodayStr() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 5));
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  /// Bola uchun bugungi `AppUsageDay` aggregat (Toshkent sanasi bilan).
  Future<AppUsageDay?> getTodayUsage(String childId) async {
    try {
      final dateStr = tashkentTodayStr();
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/app-usage',
        queryParameters: {'from': dateStr, 'to': dateStr, 'limit': 500},
      );
      final data = response.data;
      if (data == null) return null;
      final entries = data['usage'] as List<dynamic>? ?? const [];
      if (entries.isEmpty) return null;
      final apps = entries.map((m) {
        final pkg = '${(m as Map)['packageName']}';
        return AppUsageEntry.fromMap({
          'packageName': pkg,
          'appName': m['packageName'], // appName usage endpoint'da yo'q
          'totalTimeMs': (m['foregroundMs'] as num?)?.toInt() ?? 0,
          'lastTimeUsed': m['lastUsedAt'],
          // Real ikona proxy — backend ikonani saqlagan bo'lsa stream qiladi,
          // aks holda 404 → harf fallback (AppIcon errorBuilder).
          'iconUrl': _iconProxyUrl(childId, pkg),
        });
      }).toList();
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
