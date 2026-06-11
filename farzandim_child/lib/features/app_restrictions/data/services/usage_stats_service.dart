// ─────────────────────────────────────────────────────────────────────
// UsageStatsService — native Android UsageStatsManager wrapper
// ─────────────────────────────────────────────────────────────────────
//
// MethodChannel: `farzandim/usage_stats`. Native tarafi
// `android/app/src/main/kotlin/.../UsageStatsPlugin.kt`.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUsageData {
  const AppUsageData({
    required this.packageName,
    required this.appName,
    required this.totalTimeMs,
    required this.lastTimeUsed,
    this.iconBase64,
  });

  final String packageName;
  final String appName;
  final int totalTimeMs;
  final DateTime lastTimeUsed;
  final String? iconBase64;

  Duration get totalTime => Duration(milliseconds: totalTimeMs);

  factory AppUsageData.fromMap(Map<dynamic, dynamic> map) {
    return AppUsageData(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      totalTimeMs: (map['totalTimeMs'] as num).toInt(),
      lastTimeUsed: DateTime.fromMillisecondsSinceEpoch(
        (map['lastTimeUsed'] as num).toInt(),
      ),
      iconBase64: map['iconBase64'] as String?,
    );
  }
}

class InstalledAppData {
  const InstalledAppData({
    required this.packageName,
    required this.appName,
    this.iconBase64,
  });

  final String packageName;
  final String appName;
  final String? iconBase64;

  factory InstalledAppData.fromMap(Map<dynamic, dynamic> map) {
    return InstalledAppData(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      iconBase64: map['iconBase64'] as String?,
    );
  }
}

class UsageStatsService {
  static const _channel = MethodChannel('farzandim/usage_stats');

  /// PACKAGE_USAGE_STATS ruxsati bormi?
  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (e) {
      debugPrint('UsageStats hasPermission xato: $e');
      return false;
    }
  }

  /// Accessibility xizmati (RestrictionService) yoqilganmi — ota-onaga
  /// qurilma "Accessibility holati"ni ko'rsatish uchun (Block 4 / M12).
  Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } catch (e) {
      debugPrint('UsageStats isAccessibilityEnabled xato: $e');
      return false;
    }
  }

  /// Sistema sozlamalari ochish (foydalanuvchi qo'lda yoqadi).
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (e) {
      debugPrint('UsageStats openSettings xato: $e');
    }
  }

  /// Foydalanish statistikasi (oxirgi N kun).
  Future<List<AppUsageData>> getUsageStats({int days = 1}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getUsageStats',
        {'days': days},
      );
      if (result == null) return const [];
      return result
          .map((e) => AppUsageData.fromMap(e as Map<dynamic, dynamic>))
          .toList(growable: false);
    } catch (e) {
      debugPrint('UsageStats getUsageStats xato: $e');
      return const [];
    }
  }

  /// O'rnatilgan ilovalar (launcher'da ko'rinadiganlari).
  Future<List<InstalledAppData>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      if (result == null) return const [];
      return result
          .map((e) => InstalledAppData.fromMap(e as Map<dynamic, dynamic>))
          .toList(growable: false);
    } catch (e) {
      debugPrint('UsageStats getInstalledApps xato: $e');
      return const [];
    }
  }

  /// `sinceMs` dan beri foreground'ga chiqqan O'YINLAR (native CATEGORY_GAME
  /// filtri). Har paket uchun oxirgi foreground vaqti. Background isolate
  /// har siklda chaqiradi → yangi o'yin ochilsa ota-onaga push yuboriladi.
  Future<List<({String packageName, String appName, int timestamp})>>
      getRecentGameForegrounds({required int sinceMs}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getRecentGameForegrounds',
        {'sinceMs': sinceMs},
      );
      if (result == null) return const [];
      return result
          .map((e) {
            final m = e as Map<dynamic, dynamic>;
            return (
              packageName: (m['packageName'] as String?) ?? '',
              appName: (m['appName'] as String?) ?? '',
              timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
            );
          })
          .where((g) => g.packageName.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint('UsageStats getRecentGameForegrounds xato: $e');
      return const [];
    }
  }

  /// SYSTEM_ALERT_WINDOW ruxsati bormi?
  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ??
          false;
    } catch (e) {
      debugPrint('UsageStats hasOverlayPermission xato: $e');
      return false;
    }
  }

  /// Overlay sozlamalari ekrani (sistema).
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } catch (e) {
      debugPrint('UsageStats openOverlaySettings xato: $e');
    }
  }

  /// Foreground Service start (cheklov kuzatuvi).
  Future<void> startRestrictionService() async {
    try {
      await _channel.invokeMethod<void>('startRestrictionService');
    } catch (e) {
      debugPrint('UsageStats startRestrictionService xato: $e');
    }
  }

  /// Foreground Service stop.
  Future<void> stopRestrictionService() async {
    try {
      await _channel.invokeMethod<void>('stopRestrictionService');
    } catch (e) {
      debugPrint('UsageStats stopRestrictionService xato: $e');
    }
  }
}
