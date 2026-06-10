// ─────────────────────────────────────────────────────────────────────
// GameReportService — o'yin (CATEGORY_GAME) ochilganini backend'ga xabar
// ─────────────────────────────────────────────────────────────────────
//
// MUHIM: aniqlash NATIVE `RestrictionService` da bo'ladi (har 1s foreground'ni
// tekshiradi, bloklash bilan isbotlangan). Sabab: MethodChannel background
// isolate'da ishlamaydi (plugin faqat MAIN engine'ga ulanadi). Shuning uchun:
//   - Native RestrictionService o'yin foreground bo'lsa SharedPreferences
//     queue'ga yozadi (key `flutter.game.pending`, JSON string).
//   - Bu Dart service (bg isolate, onRepeatEvent ~60s) queue'ni O'QIYDI,
//     TOZALAYDI va backend'ga POST qiladi → ota-onaga "o'ynayapti" push.
// SharedPreferences cross-isolate ishlaydi (bloklash shu ko'prik bilan ishlaydi).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';

class GameReportService {
  GameReportService({required String childId, Dio? dio})
      : _childId = childId,
        _dio = dio ?? createBackendDio(TokenStorage());

  final String _childId;
  final Dio _dio;

  // Native yozadigan queue (Dart tomonda `flutter.` prefiksisiz — shared_preferences
  // plugin avtomatik qo'shadi; native `flutter.game.pending` deb o'qiydi/yozadi).
  static const _prefsKeyQueue = 'game.pending';
  // Qo'shimcha himoya: bir o'yin 5 daqiqada bir marta (native ham dedup qiladi).
  static const _dedupMs = 5 * 60 * 1000;

  final Map<String, int> _lastReported = <String, int>{};

  /// Native queue'dan ochilgan o'yinlarni o'qib, tozalab, backend'ga POST.
  Future<void> check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // MUHIM: native (boshqa isolate) yozgan qiymatni ko'rish uchun reload —
      // aks holda bu isolate o'zining eski kesh'ini o'qiydi.
      await prefs.reload();
      final raw = prefs.getString(_prefsKeyQueue);
      if (raw == null || raw.isEmpty) return;
      // Avval tozalaymiz (claim) — POST sekin bo'lsa keyingi siklda takror
      // yuborilmasin.
      await prefs.remove(_prefsKeyQueue);

      final List<dynamic> items;
      try {
        items = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final failed = <Map<String, dynamic>>[];
      for (final e in items) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final pkg = (m['pkg'] as String?) ?? '';
        final name = (m['name'] as String?) ?? pkg;
        if (pkg.isEmpty) continue;
        final last = _lastReported[pkg] ?? 0;
        if (now - last < _dedupMs) continue;
        final ok = await _report(pkg, name);
        if (ok) {
          _lastReported[pkg] = now;
        } else {
          // POST yiqildi — o'yinni YO'QOTMAYMIZ, keyingi siklda qayta urinamiz.
          failed.add(<String, dynamic>{
            'pkg': pkg,
            'name': name,
            'ts': m['ts'] ?? now,
          });
        }
      }

      if (failed.isNotEmpty) {
        await _requeue(failed);
      }
    } catch (e) {
      debugPrint('GameReportService.check xato: $e');
    }
  }

  /// POST muvaffaqiyatsiz bo'lgan o'yinlarni queue'ga qaytaradi (native shu
  /// orada qo'shgan yangi yozuvlar bilan birga — ularning ustidan yozmaymiz).
  Future<void> _requeue(List<Map<String, dynamic>> failed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_prefsKeyQueue);
      final List<dynamic> current = (raw != null && raw.isNotEmpty)
          ? (jsonDecode(raw) as List<dynamic>)
          : <dynamic>[];
      current.addAll(failed);
      await prefs.setString(_prefsKeyQueue, jsonEncode(current));
    } catch (e) {
      debugPrint('GameReportService.requeue xato: $e');
    }
  }

  /// Backend'ga POST. Muvaffaqiyatli bo'lsa `true`.
  Future<bool> _report(String packageName, String appName) async {
    try {
      await _dio.post<void>(
        '/children/$_childId/game-open',
        data: <String, dynamic>{
          'packageName': packageName,
          'appName': appName,
        },
      );
      return true;
    } catch (e) {
      debugPrint('GameReportService.report xato: $e');
      return false;
    }
  }
}
