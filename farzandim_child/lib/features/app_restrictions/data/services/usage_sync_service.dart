// ─────────────────────────────────────────────────────────────────────
// UsageSyncService — Backend installed_apps + app_usage batch sync
// ─────────────────────────────────────────────────────────────────────
//
// Backend endpoint'lar:
//   POST /api/children/:childId/app-usage        batch upsert (kunlik agg)
//   POST /api/children/:childId/installed-apps   batch upsert (ikon bilan)
//
// Taymer YO'Q — BackgroundJobs (5 daqiqalik tick, ekran yoqilishi) chaqiradi:
//   - foydalanish: `syncIfDue()` — oxirgi muvaffaqiyatdan ~5 daq o'tgan
//     bo'lsa; ikonsiz (`includeIcons: false`); jamlar o'zgarmagan bo'lsa POST
//     qilinmaydi;
//   - o'rnatilgan ilovalar (ikonlar — ENG OG'IR ish): kuniga bir marta va
//     bugungi foydalanishda yangi paket ko'rinsa; bir vaqtda bitta, xatoda
//     eksponensial kutish (2 → 60 daqiqa). Holat prefs'da (bola bo'yicha) —
//     har ishga tushishda qayta yuklanmaydi.
//
// Ruxsatni bilib bo'lmasa (fon dvigatelida plagin yo'q) — jim o'tkaziladi.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/background/data/services/background_telemetry.dart';
import 'package:farzandim_child/features/background/data/services/job_timing.dart';

class UsageSyncService {
  UsageSyncService({
    required BackendInstalledAppsRepository backendRepo,
    required UsageStatsService statsService,
    required String childId,
    DateTime Function()? clock,
    Future<SharedPreferences> Function()? prefs,
  }) : _backendRepo = backendRepo,
       _statsService = statsService,
       _childId = childId,
       // Kun kaliti ishonchli soatda (bola sanani o'zgartirsa ham to'g'ri kun).
       _clock = clock ?? TrustedClock.now,
       _prefs = prefs ?? SharedPreferences.getInstance;

  /// Foydalanish yuborish oralig'i (5 daqiqalik tick; tebranishga zaxira).
  static const syncInterval = Duration(minutes: 4, seconds: 30);

  /// `childId|YYYY-MM-DD` — o'rnatilgan ilovalar oxirgi yuklangan kun.
  static const installedSyncedKey = 'usage.installed_synced';

  /// `childId|pkg1,pkg2` — oxirgi yuklangan ro'yxatdagi paketlar.
  static const installedKnownKey = 'usage.installed_known';

  final BackendInstalledAppsRepository _backendRepo;
  final UsageStatsService _statsService;
  final String _childId;
  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _prefs;

  final Backoff _installedBackoff = Backoff(
    first: const Duration(minutes: 2),
    max: const Duration(minutes: 60),
  );

  DateTime? _lastUsageOk;
  String? _lastUsageSignature;
  Future<void>? _usageInFlight;
  Future<void>? _installedInFlight;
  Set<String>? _known;

  /// Bugungi foydalanishda ko'rinib, ro'yxat qayta yuklanishiga sabab bo'lgan
  /// paketlar (har biri uchun bir marta).
  final Set<String> _refreshedFor = {};

  /// Moslik (pairing oqimi chaqiradi): taymer yo'q, faqat muddati kelgan
  /// bo'lsa bitta sync.
  void start() {
    debugPrint('UsageSyncService.start childId=$_childId');
    unawaited(syncIfDue());
  }

  /// Oxirgi muvaffaqiyatli yuborishdan ~5 daqiqa o'tgan bo'lsa — foydalanish
  /// (va kerak bo'lsa o'rnatilgan ilovalar) yuboriladi.
  Future<void> syncIfDue() {
    final running = _usageInFlight;
    if (running != null) return running;
    if (!isDue(_lastUsageOk, _clock(), syncInterval)) return Future.value();
    final run = _syncUsage().whenComplete(() => _usageInFlight = null);
    _usageInFlight = run;
    return run;
  }

  /// Hozircha bo'shatiladigan narsa yo'q (taymer yo'q) — API mosligi uchun.
  void dispose() {}

  Future<void> _syncUsage() async {
    final startedAt = _clock();
    try {
      final hasPermission = await _statsService.tryHasPermission();
      if (hasPermission != true) {
        debugPrint('UsageSync: ruxsat yo\'q yoki noma\'lum ($hasPermission)');
        return;
      }
      final stats = await _statsService.getUsageStats(
        days: 1,
        includeIcons: false,
      );
      if (stats.isEmpty) return;

      // Toshkent kun chegarasi — backend agregatsiyasi bilan mos.
      final dayKey = tashkentDayKey(startedAt);
      final entries = [
        for (final s in stats)
          <String, dynamic>{
            'packageName': s.packageName,
            'date': dayKey,
            'foregroundMs': s.totalTimeMs,
            'openCount': 1, // Native plugin'da yo'q hozircha
            'lastUsedAt': s.lastTimeUsed.toUtc().toIso8601String(),
          },
      ];
      final signature = _signature(dayKey, stats);
      if (signature != _lastUsageSignature) {
        final ok = await _backendRepo.upsertAppUsage(
          childId: _childId,
          entries: entries,
        );
        debugPrint('UsageSync: usage ${entries.length} ta ($dayKey) ok=$ok');
        if (!ok) return;
        _lastUsageSignature = signature;
      }
      _lastUsageOk = startedAt;
      await _maybeSyncInstalled(stats);
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'usage.sync');
    }
  }

  /// Jamlar o'zgarmagan bo'lsa POST takrorlanmaydi.
  static String _signature(String dayKey, List<AppUsageData> stats) {
    final parts = [for (final s in stats) '${s.packageName}:${s.totalTimeMs}']
      ..sort();
    return '$dayKey|${parts.join(',')}';
  }

  Future<void> _maybeSyncInstalled(List<AppUsageData> stats) async {
    if (_installedInFlight != null) return;
    final now = _clock();
    if (_installedBackoff.isBlocked(now)) return;
    final prefs = await _prefs();
    final known = _known ??= _readKnown(prefs);
    final isDoneToday =
        prefs.get(installedSyncedKey) == '$_childId|${tashkentDayKey(now)}';
    final fresh = stats
        .map((s) => s.packageName)
        .where((p) => !known.contains(p) && !_refreshedFor.contains(p))
        .toList(growable: false);
    if (isDoneToday && fresh.isEmpty) return;
    if (fresh.isNotEmpty) {
      debugPrint(
        'UsageSync: yangi ilova ${fresh.length} ta — ro\'yxat yuklanadi',
      );
    }
    _refreshedFor.addAll(fresh);
    final run = _syncInstalledApps(prefs)
        .then((ok) {
          // Xato bo'lsa — kutishdan keyin shu paketlar uchun qayta urinamiz.
          if (!ok) _refreshedFor.removeAll(fresh);
        })
        .whenComplete(() => _installedInFlight = null);
    _installedInFlight = run;
    await run;
  }

  Future<bool> _syncInstalledApps(SharedPreferences prefs) async {
    final now = _clock();
    try {
      final apps = await _statsService.getInstalledApps();
      if (apps.isEmpty) {
        _installedBackoff.fail(now);
        return false;
      }
      // Backend `(childId, packageName)` upsert + lastSeenAt avtomatik.
      final batch = [
        for (final a in apps)
          <String, dynamic>{
            'packageName': a.packageName,
            'appName': a.appName,
            'isSystem': false,
            if (a.iconBase64 != null) 'iconBase64': a.iconBase64,
            // Qurilma aniqlagan haqiqiy kategoriya (bo'lsa) — backend
            // kategoriya-bloklashda paket-nomi taxminidan ustun ishlatadi.
            if (a.category != null) 'category': a.category,
          },
      ];
      final ok = await _backendRepo.upsertInstalledApps(
        childId: _childId,
        apps: batch,
      );
      debugPrint('UsageSync: installed ${batch.length} ta — ok=$ok');
      if (!ok) {
        _installedBackoff.fail(now);
        return false;
      }
      _installedBackoff.reset();
      final known = {for (final a in apps) a.packageName};
      _known = known;
      await prefs.setString(
        installedSyncedKey,
        '$_childId|${tashkentDayKey(now)}',
      );
      await prefs.setString(
        installedKnownKey,
        '$_childId|${(known.toList()..sort()).join(',')}',
      );
      return true;
    } catch (e, s) {
      _installedBackoff.fail(now);
      BackgroundTelemetry.report(e, s, 'usage.installed');
      return false;
    }
  }

  Set<String> _readKnown(SharedPreferences prefs) {
    final raw = prefs.get(installedKnownKey);
    if (raw is! String) return <String>{};
    final sep = raw.indexOf('|');
    if (sep < 0 || raw.substring(0, sep) != _childId) return <String>{};
    return raw.substring(sep + 1).split(',').where((p) => p.isNotEmpty).toSet();
  }
}
