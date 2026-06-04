// ─────────────────────────────────────────────────────────────────────
// UsageSyncService — Backend installed_apps + app_usage batch sync
// (Sprint 4.4.10)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore yozish butunlay olib tashlandi. Backend endpoint'lar:
//   POST /api/children/:childId/installed-apps   batch upsert
//   POST /api/children/:childId/app-usage        batch upsert (daily)
//
// Periodic timer:
//   - App usage: har 15 daqiqada (kunlik agg, day key)
//   - Installed apps: har 24 soatda (kichik o'zgarish, lekin
//     `lastSeenAt` har sync'da yangilanadi).

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';

class UsageSyncService {
  UsageSyncService({
    required BackendInstalledAppsRepository backendRepo,
    required UsageStatsService statsService,
    required String childId,
  })  : _backendRepo = backendRepo,
        _statsService = statsService,
        _childId = childId;

  final BackendInstalledAppsRepository _backendRepo;
  final UsageStatsService _statsService;
  final String _childId;

  Timer? _usageTimer;
  Timer? _installedTimer;

  void start() {
    debugPrint('=== UsageSyncService.start (Backend) childId=$_childId ===');

    _usageTimer?.cancel();
    _installedTimer?.cancel();

    unawaited(_syncUsage());
    unawaited(_syncInstalledApps());

    // Sync interval 60 sek — Parent UI 30 sek polling bilan birga foydalanish
    // vaqti ~1 daqiqa ichida yangilanadi. Background isolate'da ham ishlaydi
    // (ChildBackgroundTaskHandler), shuning uchun ilova fonda bo'lsa ham
    // faollik kechikmaydi.
    _usageTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_syncUsage()),
    );

    _installedTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => unawaited(_syncInstalledApps()),
    );

    debugPrint('UsageSync: Backend timer\'lar boshlandi');
  }

  Future<void> _syncUsage() async {
    try {
      final hasPermission = await _statsService.hasPermission();
      if (!hasPermission) {
        debugPrint('UsageSync: PACKAGE_USAGE_STATS ruxsati yo\'q');
        return;
      }

      final stats = await _statsService.getUsageStats(days: 1);
      if (stats.isEmpty) {
        debugPrint('UsageSync: stats bo\'sh');
        return;
      }

      final now = DateTime.now();
      final dayKey = '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      // Backend `(childId, packageName, date)` unique key upsert.
      final entries = stats
          .map(
            (s) => <String, dynamic>{
              'packageName': s.packageName,
              'date': dayKey,
              'foregroundMs': s.totalTimeMs,
              'openCount': 1, // Native plugin'da yo'q hozircha
              'lastUsedAt': s.lastTimeUsed.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false);

      final ok = await _backendRepo.upsertAppUsage(
        childId: _childId,
        entries: entries,
      );
      debugPrint(
        'UsageSync: usage ${entries.length} ta entry ($dayKey) — ok=$ok',
      );
    } catch (e) {
      debugPrint('UsageSync usage xato: $e');
    }
  }

  Future<void> _syncInstalledApps() async {
    try {
      final hasPermission = await _statsService.hasPermission();
      if (!hasPermission) {
        debugPrint('UsageSync installed: ruxsat yo\'q');
        return;
      }

      final apps = await _statsService.getInstalledApps();
      if (apps.isEmpty) {
        debugPrint('UsageSync: installed apps bo\'sh');
        return;
      }

      // Backend `(childId, packageName)` upsert + lastSeenAt avtomatik.
      // `iconBase64` payload'da yuboriladi — Backend qabul qilsa Parent
      // App ko'rsatadi. Backend rad etsa, top-level ignore qiladi.
      final batch = apps
          .map(
            (a) => <String, dynamic>{
              'packageName': a.packageName,
              'appName': a.appName,
              'isSystem': false,
              if (a.iconBase64 != null) 'iconBase64': a.iconBase64,
            },
          )
          .toList(growable: false);

      final ok = await _backendRepo.upsertInstalledApps(
        childId: _childId,
        apps: batch,
      );
      debugPrint(
        'UsageSync: installed ${batch.length} ta upsert — ok=$ok',
      );
    } catch (e) {
      debugPrint('UsageSync installed xato: $e');
    }
  }

  void dispose() {
    _usageTimer?.cancel();
    _installedTimer?.cancel();
    _usageTimer = null;
    _installedTimer = null;
  }
}
