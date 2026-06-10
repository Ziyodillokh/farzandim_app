// ─────────────────────────────────────────────────────────────────────
// GameReportService — o'yin (CATEGORY_GAME) ochilganini backend'ga xabar
// ─────────────────────────────────────────────────────────────────────
//
// Background isolate (ChildBackgroundTaskHandler.onRepeatEvent) har ~60s
// `check()` chaqiradi. Native `getRecentGameForegrounds` faqat O'YINLARNI
// (ApplicationInfo.category == CATEGORY_GAME) qaytaradi. Yangi o'yin
// ochilgan bo'lsa backend'ga POST → ota-onaga "o'yin o'ynayapti" push +
// "Bloklash" tugmasi. Bir o'yin [_dedupMs] ichida faqat bir marta (spam yo'q).

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';

class GameReportService {
  GameReportService({
    required String childId,
    Dio? dio,
    UsageStatsService? stats,
  })  : _childId = childId,
        _dio = dio ?? createBackendDio(TokenStorage()),
        _stats = stats ?? UsageStatsService();

  final String _childId;
  final Dio _dio;
  final UsageStatsService _stats;

  // Bir o'yin shu muddat ichida bir marta xabar qilinadi (takror push yo'q).
  static const _dedupMs = 5 * 60 * 1000;

  int _lastCheckMs = 0;
  final Map<String, int> _lastReported = <String, int>{};

  /// Oxirgi tekshiruvdan beri ochilgan o'yinlarni olib, backend'ga xabar.
  Future<void> check() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Birinchi siklda oxirgi 60s — service endi ishga tushgan.
    final since = _lastCheckMs == 0 ? now - 60 * 1000 : _lastCheckMs;
    _lastCheckMs = now;
    try {
      final games = await _stats.getRecentGameForegrounds(sinceMs: since);
      for (final g in games) {
        final last = _lastReported[g.packageName] ?? 0;
        if (now - last < _dedupMs) continue;
        _lastReported[g.packageName] = now;
        await _report(g.packageName, g.appName);
      }
    } catch (e) {
      debugPrint('GameReportService.check xato: $e');
    }
  }

  Future<void> _report(String packageName, String appName) async {
    try {
      await _dio.post<void>(
        '/children/$_childId/game-open',
        data: <String, dynamic>{
          'packageName': packageName,
          'appName': appName,
        },
      );
    } catch (e) {
      debugPrint('GameReportService.report xato: $e');
    }
  }
}
