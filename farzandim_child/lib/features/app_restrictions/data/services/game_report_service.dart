// ─────────────────────────────────────────────────────────────────────
// GameReportService — o'yin (CATEGORY_GAME) ochilganini backend'ga xabar
// ─────────────────────────────────────────────────────────────────────
//
// Aniqlash NATIVE `RestrictionService` da (har 1 s foreground'ni tekshiradi):
// o'yin ochilsa prefs queue'ga yozadi (`flutter.game.pending`, JSON ro'yxat:
// {pkg, name, ts, at}; `at` — ochilgan vaqt, epoch ms). Bu Dart servis
// (BackgroundJobs: tick, ekran yoqilishi, internet qaytishi) queue'ni oladi
// va POST /children/:id/game-open qiladi (`openedAt` bilan) → ota-onaga
// "o'ynayapti" push.
//
//   - queue o'qilishi bilan darhol tozalanadi (native yangi yozuv qo'shishiga
//     oraliq — bitta platforma chaqiruvi);
//   - 10 daqiqadan eski voqea yuborilmaydi (kechikkan xabar "hozir
//     o'ynayapti" bo'lib ko'rinmasin; backend ham tashlaydi);
//   - yuborilmaganlari xotirada qayta urinish uchun qoladi (10 daqiqagacha).

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:farzandim_child/features/background/data/services/background_telemetry.dart';

@immutable
class _GameOpen {
  const _GameOpen({required this.pkg, required this.name, required this.atMs});

  final String pkg;
  final String name;

  /// Ochilgan vaqt — qurilma soati, epoch ms.
  final int atMs;
}

class GameReportService {
  GameReportService({
    required String childId,
    Dio? dio,
    DateTime Function()? clock,
    int Function()? clockOffsetMs,
    Future<SharedPreferences> Function()? prefs,
  }) : _childId = childId,
       _dio = dio ?? createBackendDio(TokenStorage()),
       _clock = clock ?? DateTime.now,
       _clockOffsetMs = clockOffsetMs ?? (() => TrustedClock.offsetMs),
       _prefs = prefs ?? SharedPreferences.getInstance;

  final String _childId;
  final Dio _dio;

  /// Qurilma soati — native `at` bilan bir asos.
  final DateTime Function() _clock;

  /// Server vaqtiga o'tkazish (`openedAt` server soatida bo'lsin).
  final int Function() _clockOffsetMs;
  final Future<SharedPreferences> Function() _prefs;

  // Native yozadigan queue (Dart tomonda `flutter.` prefiksisiz).
  static const queueKey = 'game.pending';

  /// Bundan eski voqea yuborilmaydi.
  static const maxAge = Duration(minutes: 10);

  // Bir o'yin 5 daqiqada bir marta (native ham dedup qiladi).
  static const _dedupMs = 5 * 60 * 1000;
  static const _maxRetry = 50;

  final Map<String, int> _lastReportedAt = <String, int>{};
  final List<_GameOpen> _retry = <_GameOpen>[];
  Future<void>? _inFlight;

  /// Queue'ni olib backend'ga yuboradi. Bir vaqtda bitta.
  Future<void> check() {
    final running = _inFlight;
    if (running != null) return running;
    final run = _check().whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<void> _check() async {
    try {
      final claimed = await _drainQueue();
      final pending = [..._retry, ...claimed];
      _retry.clear();
      if (pending.isEmpty) return;
      final nowMs = _clock().millisecondsSinceEpoch;
      for (final g in pending) {
        if (nowMs - g.atMs > maxAge.inMilliseconds) continue;
        final last = _lastReportedAt[g.pkg];
        if (last != null && (g.atMs - last).abs() < _dedupMs) continue;
        if (await _report(g)) {
          _lastReportedAt[g.pkg] = g.atMs;
        } else if (_retry.length < _maxRetry) {
          _retry.add(g);
        }
      }
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'games.check');
    }
  }

  /// Native (boshqa yozuvchi) qiymatini ko'rish uchun reload, so'ng DARHOL
  /// tozalash — o'qish va o'chirish orasida native yangi yozuv qo'shishiga
  /// imkon deyarli qolmaydi.
  Future<List<_GameOpen>> _drainQueue() async {
    final prefs = await _prefs();
    await prefs.reload();
    final raw = prefs.get(queueKey);
    if (raw is! String || raw.isEmpty) return const [];
    await prefs.remove(queueKey);
    return _parse(raw, _clock().millisecondsSinceEpoch);
  }

  static List<_GameOpen> _parse(String raw, int nowMs) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map && e['pkg'] is String && (e['pkg'] as String).isNotEmpty)
          _GameOpen(
            pkg: e['pkg'] as String,
            name: (e['name'] as String?) ?? e['pkg'] as String,
            atMs: _timestamp(e['at']) ?? _timestamp(e['ts']) ?? nowMs,
          ),
    ];
  }

  static int? _timestamp(Object? raw) =>
      raw is num && raw > 0 ? raw.toInt() : null;

  /// Backend'ga POST. Yuborildi (yoki qayta urinish foydasiz) — `true`.
  Future<bool> _report(_GameOpen g) async {
    final openedAt = DateTime.fromMillisecondsSinceEpoch(
      g.atMs + _clockOffsetMs(),
      isUtc: true,
    );
    try {
      await _dio.post<void>(
        '/children/$_childId/game-open',
        data: <String, dynamic>{
          'packageName': g.pkg,
          'appName': g.name,
          'openedAt': openedAt.toIso8601String(),
        },
      );
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Rad etilgan so'rov (400/403/404...) qayta yuborilsa ham o'tmaydi.
      final isPermanent =
          status != null &&
          status >= 400 &&
          status < 500 &&
          status != 401 &&
          status != 408 &&
          status != 429;
      debugPrint('GameReportService.report xato: $status');
      return isPermanent;
    }
  }
}
