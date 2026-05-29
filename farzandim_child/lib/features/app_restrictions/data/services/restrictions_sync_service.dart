// ─────────────────────────────────────────────────────────────────────
// RestrictionsSyncService — Schedule + AppLimit unified sync
// (Sprint 4.4.25)
// ─────────────────────────────────────────────────────────────────────
//
// 2 ta Backend manba'sini birlashtirib SharedPreferences'ga yozadi:
//
//   1. **Schedule** (`AppSchedulePolicy`, vaqt-window BLOCK/ALLOW)
//      Misol: 21:00–07:00 → barcha apps BLOCK
//      Native plugin'ga: `blocked_packages = "*"` (wildcard)
//
//   2. **AppLimit** (per-package quota)
//      Misol: com.youtube → 15 min/kun, com.tiktok → block
//      Native plugin'ga:
//        - dailyLimitMs == 0 → `blocked_packages` ga packageName qo'shish
//        - dailyLimitMs > 0  → `limits` ga `packageName:minutes` formatda
//
// Sync trigger'lar:
//   - Pairing tugagach `start(childId)`
//   - Har 5 daqiqada Timer.periodic
//   - WS `app_limit:created/updated/deleted` event paytida `sync()` (public)
//   - WS `schedule:created/updated/deleted` event paytida `sync()` (public)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

class RestrictionsSyncService {
  RestrictionsSyncService({
    required BackendScheduleRepository scheduleRepo,
    required BackendAppLimitRepository appLimitRepo,
  })  : _scheduleRepo = scheduleRepo,
        _appLimitRepo = appLimitRepo;

  static const _prefsKeyBlocked = 'restriction.blocked_packages';
  static const _prefsKeyLimits = 'restriction.limits';
  static const _wildcardAll = '*';

  final BackendScheduleRepository _scheduleRepo;
  final BackendAppLimitRepository _appLimitRepo;
  Timer? _syncTimer;
  String? _childId;

  /// Sync boshlash. Pairing tugagandan keyin chaqiriladi.
  /// Har 5 daqiqada `_syncNow()` chaqiradi (background safety net).
  void start({required String childId}) {
    _childId = childId;
    _syncTimer?.cancel();

    debugPrint('RestrictionsSync: start $childId');

    unawaited(_syncNow());
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_syncNow()),
    );
  }

  /// WS event handler'lar uchun public — `app_limit:*` yoki `schedule:*`
  /// kelganda darhol refresh.
  Future<void> sync() => _syncNow();

  Future<void> _syncNow() async {
    if (_childId == null) return;
    try {
      // Parallel fetch — ikkalasi mustaqil.
      final results = await Future.wait([
        _scheduleRepo.getSchedules(_childId!),
        _appLimitRepo.getLimits(_childId!),
      ]);
      final policies = results[0] as List<AppSchedulePolicy>;
      final limits = results[1] as List<AppLimit>;

      // 1. Schedule window'da BLOCK bormi?
      final isWindowBlock = _isCurrentlyBlockedByWindow(policies);

      // 2. AppLimit'larni ikki ro'yxatga ajratish:
      //    - to'liq block (dailyLimitMs == 0) → blocked_packages
      //    - vaqt cheklovi (dailyLimitMs > 0) → limits
      final blockedPkgs = <String>[];
      final limitEntries = <String>[];
      for (final l in limits) {
        if (!l.isActive) continue;
        if (l.isFullBlock) {
          blockedPkgs.add(l.packageName);
        } else if (l.dailyLimitMinutes > 0) {
          limitEntries.add('${l.packageName}:${l.dailyLimitMinutes}');
        }
      }

      // 3. Schedule whole-window BLOCK bo'lsa `*` qo'shish (native
      //    plugin'da wildcard "har qanday foreground'ni block").
      if (isWindowBlock) {
        blockedPkgs.add(_wildcardAll);
      }

      // 4. SharedPreferences yozish (comma-separated).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyBlocked, blockedPkgs.join(','));
      await prefs.setString(_prefsKeyLimits, limitEntries.join(','));

      debugPrint(
        'RestrictionsSync: schedules=${policies.length} '
        'limits=${limits.length} '
        'blockedPkgs=${blockedPkgs.length} '
        'limitEntries=${limitEntries.length} '
        'windowBlock=$isWindowBlock',
      );
    } catch (e) {
      debugPrint('RestrictionsSync xato: $e');
    }
  }

  /// Hozirgi vaqt biror Schedule BLOCK window ichidami?
  static bool _isCurrentlyBlockedByWindow(List<AppSchedulePolicy> policies) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final isoWeekday = now.weekday; // 1..7

    for (final p in policies) {
      if (!p.isActive) continue;
      if (!p.daysOfWeek.contains(isoWeekday)) continue;
      final startMin = _parseHhMm(p.startTime);
      final endMin = _parseHhMm(p.endTime);
      if (startMin == null || endMin == null) continue;
      if (_isInWindow(nowMinutes, startMin, endMin) && p.action == 'BLOCK') {
        return true;
      }
    }
    return false;
  }

  static int? _parseHhMm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Vaqt window ichidami (wrap-around qo'llab-quvvatlanadi).
  /// Masalan: 22:00–06:00 — kechqurun va ertalab.
  static bool _isInWindow(int nowMinutes, int startMin, int endMin) {
    if (startMin == endMin) return false;
    if (startMin < endMin) {
      return nowMinutes >= startMin && nowMinutes < endMin;
    }
    // Wrap-around (kechadan ertalabga).
    return nowMinutes >= startMin || nowMinutes < endMin;
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
