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
//
// 1.0.20 (batareya / barqarorlik):
//   • YAGONA flusher: flush()'ni BackgroundJobs egasi chaqiradi (Android —
//     FGS isolate; iOS yoki FGS ishlamayotganda — UI isolate). Isolate
//     ichida bir vaqtda bitta flush.
//   • Birinchi tarmoq xatosi / timeout / 5xx / 401 / 408 / 429 da to'xtaydi
//     va eksponensial kutadi: 1 → 2 → 4 → … → 30 daqiqa. Keyingi urinish
//     vaqti prefs'da (qayta ishga tushganda ham saqlanadi).
//   • Bir flush'da ko'pi bilan 50 ta item.
//   • enqueue va flush ro'yxatni reload → o'zgartirish → yozish bilan isolate
//     ichidagi bitta qulf ostida yangilaydi; tarmoq so'rovlari qulfdan
//     tashqarida. Flush faqat O'ZI yuborgan/tashlagan id'larni olib tashlaydi —
//     flush paytida qo'shilgan itemlar yo'qolmaydi.

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
const _nextAttemptKey = 'offline_buffer.next_attempt_ms';
const _failuresKey = 'offline_buffer.failures';
const _maxItems = 1000;
const _maxItemsPerFlush = 50;
const Duration _maxAge = Duration(hours: 24);
const Duration _backoffBase = Duration(minutes: 1);
const Duration _backoffMax = Duration(minutes: 30);

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

/// Bitta item yuborish natijasi.
enum _Delivery { sent, dropped, retryLater }

class OfflineBuffer {
  /// [clock] va [hasNetwork] — testlar uchun.
  OfflineBuffer({
    Dio? dio,
    TokenStorage? tokenStorage,
    DateTime Function()? clock,
    Future<bool> Function()? hasNetwork,
  }) : _tokenStorage = tokenStorage ?? TokenStorage(),
       _clock = clock ?? DateTime.now,
       _hasNetwork = hasNetwork ?? _connectivityHasNetwork {
    // MUHIM: refresh interceptor'li UMUMIY dio (createBackendDio) —
    // avval bu yerda yalang'och dio bor edi (faqat access token header).
    // Access token 15 daqiqada eskiradi: offline'da yig'ilgan butun buffer
    // flush'da 401 olib TO'LIQ DROP bo'lardi (4xx=discard tarmog'i).
    _dio = dio ?? createBackendDio(_tokenStorage);
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final DateTime Function() _clock;
  final Future<bool> Function() _hasNetwork;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Isolate ichidagi BARCHA nusxalar uchun umumiy (LocationService va
  // BackgroundJobs alohida nusxa yaratadi, lekin ro'yxat bitta).
  static Future<void> _lockTail = Future<void>.value();
  static Future<void>? _flushInFlight;

  /// Connectivity listener — internet qaytganda flush (kutishsiz).
  /// Faqat flusher isolate'da chaqiring (BackgroundJobs egasi).
  void start() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) {
        unawaited(flush(ignoreBackoff: true));
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
      final total = await _locked(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final item = _BufferedRequest(
          id: _generateId(),
          endpoint: endpoint,
          method: method,
          body: body,
          createdAt: _clock().millisecondsSinceEpoch,
        );
        // TTL + max cap
        final pruned = _prune([..._decode(prefs.getString(_prefsKey)), item]);
        await _write(prefs, pruned);
        return pruned.length;
      });
      debugPrint('OfflineBuffer: enqueued $method $endpoint (total $total)');
    } catch (e) {
      debugPrint('OfflineBuffer.enqueue xato: $e');
    }
  }

  /// Buffer boshidan ko'pi bilan 50 ta itemni yuboradi. Birinchi vaqtinchalik
  /// xatoda to'xtaydi va kutish muddatini oshiradi; kutish tugamaguncha
  /// chaqiruvlar hech narsa yubormaydi ([ignoreBackoff] — internet qaytganda).
  Future<void> flush({bool ignoreBackoff = false}) {
    final pending = _flushInFlight;
    if (pending != null) return pending;
    final run = _flush(ignoreBackoff: ignoreBackoff);
    _flushInFlight = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_flushInFlight, run)) _flushInFlight = null;
      }),
    );
    return run;
  }

  /// Buffer'dagi item soni (UI uchun).
  Future<int> pendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return _prune(_decode(prefs.getString(_prefsKey))).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _flush({required bool ignoreBackoff}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final batch = await _locked(() => _takeBatch(prefs, ignoreBackoff));
      if (batch.isEmpty) return;

      // Tarmoq yo'q — urinish hisoblanmaydi (kutish oshmaydi).
      if (!await _hasNetwork()) {
        debugPrint('OfflineBuffer.flush: net yo\'q, skip');
        return;
      }

      final done = <String>{};
      var stopped = false;
      for (final req in batch) {
        final delivery = await _deliver(req);
        if (delivery == _Delivery.retryLater) {
          stopped = true;
          break;
        }
        done.add(req.id);
      }

      await _locked(() async {
        await prefs.reload();
        if (done.isNotEmpty) {
          final current = _decode(prefs.getString(_prefsKey));
          final remaining = [
            for (final r in current)
              if (!done.contains(r.id)) r,
          ];
          await _write(prefs, remaining);
        }
        await _recordOutcome(prefs, failed: stopped);
      });
      debugPrint(
        'OfflineBuffer.flush: ${done.length} ta tugadi'
        '${stopped ? ', xato — kutiladi' : ''}',
      );
    } catch (e) {
      debugPrint('OfflineBuffer.flush xato: $e');
    }
  }

  /// Kutish tugaganmi tekshiradi, eskirganlarni tozalaydi va navbatdagi
  /// partiyani qaytaradi (bo'sh — yuboriladigan narsa yo'q).
  Future<List<_BufferedRequest>> _takeBatch(
    SharedPreferences prefs,
    bool ignoreBackoff,
  ) async {
    await prefs.reload();
    final nowMs = _clock().millisecondsSinceEpoch;
    final waitMs = (prefs.getInt(_nextAttemptKey) ?? 0) - nowMs;
    // Eng uzun kutishdan ham uzoq — soat orqaga surilgan: e'tiborsiz.
    if (!ignoreBackoff && waitMs > 0 && waitMs <= _backoffMax.inMilliseconds) {
      return const [];
    }
    final items = _decode(prefs.getString(_prefsKey));
    final fresh = _prune(items);
    if (fresh.length != items.length) await _write(prefs, fresh);
    return fresh.take(_maxItemsPerFlush).toList();
  }

  Future<_Delivery> _deliver(_BufferedRequest req) async {
    try {
      await _dio.request<void>(
        req.endpoint,
        data: req.body,
        options: Options(method: req.method),
      );
      return _Delivery.sent;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // Javob yo'q (tarmoq/timeout), 5xx, 401 (refresh ham yiqildi), 408,
      // 429 — VAQTINCHA: qolganlari saqlanadi, keyinroq.
      if (code == null ||
          code >= 500 ||
          code == 401 ||
          code == 408 ||
          code == 429) {
        return _Delivery.retryLater;
      }
      // Haqiqiy validation reject — retry foydasiz → discard.
      debugPrint('OfflineBuffer.flush: ${req.endpoint} $code — drop');
      return _Delivery.dropped;
    } catch (e) {
      debugPrint('OfflineBuffer.flush: ${req.endpoint} — $e');
      return _Delivery.retryLater;
    }
  }

  Future<void> _recordOutcome(
    SharedPreferences prefs, {
    required bool failed,
  }) async {
    if (!failed) {
      if (prefs.containsKey(_failuresKey)) await prefs.remove(_failuresKey);
      if (prefs.containsKey(_nextAttemptKey)) {
        await prefs.remove(_nextAttemptKey);
      }
      return;
    }
    final failures = (prefs.getInt(_failuresKey) ?? 0) + 1;
    final next = _clock().add(backoffFor(failures));
    await prefs.setInt(_failuresKey, failures);
    await prefs.setInt(_nextAttemptKey, next.millisecondsSinceEpoch);
  }

  /// [failures] ketma-ket xatodan keyingi kutish: 1, 2, 4, … 30 daqiqa.
  @visibleForTesting
  static Duration backoffFor(int failures) {
    if (failures <= 0) return Duration.zero;
    final exponent = math.min(failures - 1, 5);
    final delay = _backoffBase * (1 << exponent);
    return delay > _backoffMax ? _backoffMax : delay;
  }

  /// Isolate ichida ro'yxat o'qish-o'zgartirish-yozishni ketma-ket qiladi.
  static Future<T> _locked<T>(Future<T> Function() action) {
    final previous = _lockTail;
    final release = Completer<void>();
    _lockTail = release.future;
    return previous.then((_) => action()).whenComplete(release.complete);
  }

  static Future<void> _write(
    SharedPreferences prefs,
    List<_BufferedRequest> items,
  ) async {
    if (items.isEmpty) {
      if (prefs.containsKey(_prefsKey)) await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(
      _prefsKey,
      jsonEncode(items.map((r) => r.toJson()).toList()),
    );
  }

  static List<_BufferedRequest> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (m) =>
                _BufferedRequest.fromJson((m as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<_BufferedRequest> _prune(List<_BufferedRequest> items) {
    final now = _clock().millisecondsSinceEpoch;
    final maxAgeMs = _maxAge.inMilliseconds;
    final fresh = items.where((r) => now - r.createdAt < maxAgeMs).toList();
    if (fresh.length > _maxItems) {
      return fresh.sublist(fresh.length - _maxItems);
    }
    return fresh;
  }

  static Future<bool> _connectivityHasNetwork() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      return conn.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Noma'lum — urinib ko'ramiz (xato bo'lsa kutish oshadi).
      return true;
    }
  }

  String _generateId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @visibleForTesting
  static void resetForTest() {
    _lockTail = Future<void>.value();
    _flushInFlight = null;
  }
}
