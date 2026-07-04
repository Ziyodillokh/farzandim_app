// Bola qurilmasidagi o'rnatilgan ilovalar va foydalanish statistikasi
// (parent tomonda read-only).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/core/cache/swr_cache.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/utils/app_brand.dart';
import 'package:farzandim/core/utils/tashkent_time.dart' as tz;
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendAppUsageRepositoryProvider = Provider<BackendAppUsageRepository>((
  ref,
) {
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
      // Xom javob disk-keshga — keyingi ochilishda serverni kutmasdan
      // darhol ko'rsatish uchun.
      unawaited(SwrCache.write('installed_apps:$childId', list));
      return _mapInstalledApps(childId, list);
    } on DioException catch (e) {
      // Xatoni yutmaymiz — offline'da yolg'on "ilovalar yo'q" ko'rinardi.
      debugPrint('BackendAppUsageRepository.getInstalledApps: $e');
      rethrow;
    }
  }

  /// Keshdagi oxirgi ro'yxat (stale). Yo'q yoki buzuq bo'lsa null.
  Future<List<AppUsageEntry>?> getCachedInstalledApps(String childId) async {
    final cached = await SwrCache.read('installed_apps:$childId');
    if (cached == null) return null;
    final (data, _) = cached;
    if (data is! List) return null;
    try {
      return _mapInstalledApps(childId, data);
    } catch (_) {
      return null;
    }
  }

  List<AppUsageEntry> _mapInstalledApps(String childId, List<dynamic> list) {
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
        // Mashhur ilovani nomlaymiz / paket nomini chiroyli formatga
        // keltiramiz ("org.telegram.messenger" → "Telegram").
        'appName': friendlyAppName(pkg, map['appName'] as String?),
        'totalTimeMs': 0,
        'lastTimeUsed': map['lastSeenAt'],
        'iconBase64': map['iconBase64'],
        'iconUrl': iconUrl,
      });
    }).toList();
  }

  /// Ilova ikonasi proxy URL — backend MinIO'dan rasmni stream qiladi.
  String _iconProxyUrl(String childId, String packageName) =>
      '${_dio.options.baseUrl}/children/$childId/installed-apps/'
      '${Uri.encodeComponent(packageName)}/icon';

  /// 7 kunlik kunlik totals — backend `/weekly` (system filtrlangan + UTC+5).
  /// `endDate` API mosligi uchun saqlanadi (server o'zi hisoblaydi).
  ///
  /// Xato bu yerda yutilmaydi: avval xatoda 7 kun "0" qaytarilib, tarmoq
  /// blip'ida ekran vaqti "0 daqiqa"ga tushib qolardi. Rethrow bilan
  /// StreamProvider oldingi qiymatni saqlab turadi.
  Future<List<DailyUsageTotal>> getWeeklyTotals({
    required String childId,
    required DateTime endDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/children/$childId/app-usage/weekly',
    );
    final days = response.data?['days'] as List<dynamic>? ?? const [];
    // Xom javob disk-keshga (per-child).
    unawaited(SwrCache.write('weekly_usage:$childId', days));
    return _mapWeekly(days);
  }

  /// Haftalik qadamlar — backend `/weekly-report` javobining `steps` bo'limi
  /// (`{days: [{date, steps}], weekTotal}`). Dashboard qadamlar kartasi uchun.
  Future<WeeklySteps> getWeeklySteps(String childId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/children/$childId/weekly-report',
    );
    final steps = response.data?['steps'] as Map<String, dynamic>? ?? const {};
    final days = (steps['days'] as List<dynamic>? ?? const []).map((d) {
      final m = d as Map;
      return DailySteps(
        date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
        steps: (m['steps'] as num?)?.toInt() ?? 0,
      );
    }).toList();
    return WeeklySteps(
      days: days,
      weekTotal: (steps['weekTotal'] as num?)?.toInt() ?? 0,
    );
  }

  /// Keshdagi oxirgi haftalik totals (stale). Yo'q yoki buzuq bo'lsa null.
  Future<List<DailyUsageTotal>?> getCachedWeeklyTotals(String childId) async {
    final cached = await SwrCache.read('weekly_usage:$childId');
    if (cached == null) return null;
    final (data, _) = cached;
    if (data is! List) return null;
    try {
      return _mapWeekly(data);
    } catch (_) {
      return null;
    }
  }

  List<DailyUsageTotal> _mapWeekly(List<dynamic> days) {
    return days.map((d) {
      final m = d as Map;
      final date = DateTime.tryParse('${m['date']}') ?? DateTime.now();
      return DailyUsageTotal(
        date: date,
        totalMs: (m['totalMs'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  /// Toshkent (UTC+5) bugungi sanasi "YYYY-MM-DD".
  static String tashkentTodayStr() {
    final t = tz.tashkentNow();
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
        final map = m as Map;
        final pkg = '${map['packageName']}';
        // Usage endpoint ko'pincha nom bermaydi — friendlyAppName mashhur
        // ilovani nomlaydi yoki paket nomini chiroyli formatga keltiradi
        // ("org.telegram.messenger" → "Telegram").
        final realName = map['appName'] as String?;
        return AppUsageEntry.fromMap({
          'packageName': pkg,
          'appName': friendlyAppName(pkg, realName),
          'totalTimeMs': (map['foregroundMs'] as num?)?.toInt() ?? 0,
          'lastTimeUsed': map['lastUsedAt'],
          // Real ikona proxy — backend ikonani saqlagan bo'lsa stream qiladi,
          // aks holda 404 → harf fallback (AppIcon errorBuilder).
          'iconUrl': _iconProxyUrl(childId, pkg),
        });
      }).toList();
      return AppUsageDay(date: dateStr, updatedAt: DateTime.now(), apps: apps);
    } on DioException catch (e) {
      // Xatoni yutmaymiz — offline'da yolg'on "0 daqiqa" ko'rinardi.
      debugPrint('BackendAppUsageRepository.getTodayUsage: $e');
      rethrow;
    }
  }
}

/// Dashboard ScreenTimeChart uchun kunlik aggregat.
class DailyUsageTotal {
  const DailyUsageTotal({required this.date, required this.totalMs});
  final DateTime date;
  final int totalMs;

  double get hours => totalMs / 3600000;
}

/// Bir kunlik qadamlar (weekly-report `steps.days` elementi).
class DailySteps {
  /// `DailySteps` konstruktor.
  const DailySteps({required this.date, required this.steps});

  /// Sana.
  final DateTime date;

  /// Shu kundagi qadamlar.
  final int steps;
}

/// Haftalik qadamlar to'plami (weekly-report `steps` bo'limi).
class WeeklySteps {
  /// `WeeklySteps` konstruktor.
  const WeeklySteps({required this.days, required this.weekTotal});

  /// Kunlik qadamlar (oxirgi 7 kun).
  final List<DailySteps> days;

  /// Hafta jami.
  final int weekTotal;
}
