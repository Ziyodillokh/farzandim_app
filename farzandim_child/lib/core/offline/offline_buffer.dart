// ─────────────────────────────────────────────────────────────────────
// OfflineBuffer — Internet/Location o'chiq paytda data buffer
// ─────────────────────────────────────────────────────────────────────
//
// Bola telefoni internet yoki location o'chiq bo'lganda location va
// boshqa POST data SharedPreferences'ga 24 soat saqlanadi. Connectivity
// qaytganda flush — FIFO tartibida Backend'ga yuboradi.
//
// Sxema (har bir item):
// ```json
// {
//   "id": "uuid",
//   "endpoint": "/location",
//   "method": "POST",
//   "body": {...},
//   "createdAt": 1715944320000  // epoch ms
// }
// ```
//
// Maksimum item: 1000 (taxminan 1 daqiqada 1 location → 24 soat = 1440).
// Eski itemlar avtomatik tushib ketadi (TTL 24 soat).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';

const _prefsKey = 'offline_buffer_v1';
const _maxItems = 1000;
const Duration _maxAge = Duration(hours: 24);

class _BufferedRequest {
  _BufferedRequest({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.createdAt,
  });

  factory _BufferedRequest.fromJson(Map<String, dynamic> json) {
    return _BufferedRequest(
      id: json['id'] as String,
      endpoint: json['endpoint'] as String,
      method: (json['method'] as String?) ?? 'POST',
      body: (json['body'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: json['createdAt'] as int,
    );
  }

  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final int createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'createdAt': createdAt,
      };
}

class OfflineBuffer {
  OfflineBuffer({Dio? dio, TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage() {
    // MUHIM: refresh interceptor'li UMUMIY dio (createBackendDio) —
    // avval bu yerda yalang'och dio bor edi (faqat access token header).
    // Access token 15 daqiqada eskiradi: offline'da yig'ilgan butun buffer
    // flush'da 401 olib TO'LIQ DROP bo'lardi (4xx=discard tarmog'i).
    _dio = dio ?? createBackendDio(_tokenStorage);
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _flushing = false;

  /// Connectivity listener — internet qaytganda flush boshlanadi.
  void start() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasNet) {
        unawaited(flush());
      }
    });
    debugPrint('OfflineBuffer: started, listening connectivity');
    // App startup'da ham flush — eski qoldiqlar yuborilsin.
    unawaited(flush());
  }

  void stop() {
    _connSub?.cancel();
    _connSub = null;
  }

  /// Yangi request'ni buffer'ga qo'shish.
  Future<void> enqueue({
    required String endpoint,
    required Map<String, dynamic> body,
    String method = 'POST',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await _readItems(prefs);
      final id = _generateId();
      items.add(_BufferedRequest(
        id: id,
        endpoint: endpoint,
        method: method,
        body: body,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      // TTL + max cap
      final pruned = _prune(items);
      await prefs.setString(
        _prefsKey,
        jsonEncode(pruned.map((r) => r.toJson()).toList()),
      );
      debugPrint(
        'OfflineBuffer: enqueued $method $endpoint (total ${pruned.length})',
      );
    } catch (e) {
      debugPrint('OfflineBuffer.enqueue xato: $e');
    }
  }

  /// Buffer'dagi barcha itemlarni Backend'ga yuborish.
  /// Connectivity yoki manual chaqiruv.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var items = await _readItems(prefs);
      items = _prune(items);
      if (items.isEmpty) {
        await prefs.remove(_prefsKey);
        return;
      }

      // Connectivity tezkor tekshiruvi
      final conn = await Connectivity().checkConnectivity();
      final hasNet =
          conn.any((r) => r != ConnectivityResult.none);
      if (!hasNet) {
        debugPrint('OfflineBuffer.flush: net yo\'q, skip');
        return;
      }

      final remaining = <_BufferedRequest>[];
      for (var i = 0; i < items.length; i++) {
        final req = items[i];
        try {
          await _dio.request<void>(
            req.endpoint,
            data: req.body,
            options: Options(method: req.method),
          );
          // OK — discard
        } on DioException catch (e) {
          final code = e.response?.statusCode ?? 0;
          if (code == 401) {
            // Dio'da refresh interceptor bor — 401 bu yerga yetib kelgani
            // refresh'ning O'ZI yiqilganini bildiradi (tarmoq/refresh-token).
            // Bu TRANSIENT: butun qolgan bufferni saqlab, siklni to'xtatamiz
            // (yuzlab mahkum so'rov otmaslik uchun). Keyingi flush'da qayta.
            remaining
              ..add(req)
              ..addAll(items.skip(i + 1));
            debugPrint(
              'OfflineBuffer.flush: 401 (refresh yiqildi) — saqlab to\'xtatildi',
            );
            break;
          }
          if (code >= 400 && code < 500) {
            // Haqiqiy validation reject — retry foydasiz → discard.
            debugPrint(
              'OfflineBuffer.flush: ${req.endpoint} $code — drop',
            );
            continue;
          }
          // 5xx/network — keep in buffer for next attempt
          remaining.add(req);
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove(_prefsKey);
        debugPrint('OfflineBuffer.flush: all ${items.length} sent');
      } else {
        await prefs.setString(
          _prefsKey,
          jsonEncode(remaining.map((r) => r.toJson()).toList()),
        );
        debugPrint(
          'OfflineBuffer.flush: ${items.length - remaining.length} sent, '
          '${remaining.length} kept for retry',
        );
      }
    } catch (e) {
      debugPrint('OfflineBuffer.flush xato: $e');
    } finally {
      _flushing = false;
    }
  }

  /// Buffer'dagi item soni (UI uchun).
  Future<int> pendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await _readItems(prefs);
      return _prune(items).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<_BufferedRequest>> _readItems(SharedPreferences prefs) async {
    // MUHIM: bg isolate enqueue qiladi, flush boshqa isolate'da bo'lishi
    // mumkin — har isolate'ning SharedPreferences keshi ALOHIDA. reload'siz
    // eski (bo'sh) kesh o'qilib, flush'dagi prefs.remove() boshqa isolate
    // yozgan itemlarni o'chirib yuborardi.
    await prefs.reload();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((m) => _BufferedRequest.fromJson(
                (m as Map).cast<String, dynamic>(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<_BufferedRequest> _prune(List<_BufferedRequest> items) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = _maxAge.inMilliseconds;
    final fresh = items
        .where((r) => now - r.createdAt < maxAgeMs)
        .toList();
    if (fresh.length > _maxItems) {
      return fresh.sublist(fresh.length - _maxItems);
    }
    return fresh;
  }

  String _generateId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
