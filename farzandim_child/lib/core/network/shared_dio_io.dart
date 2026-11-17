// ─────────────────────────────────────────────────────────────────────
// Umumiy backend Dio (Android / iOS) — ulanishlar qayta ishlatiladi
// ─────────────────────────────────────────────────────────────────────
//
// Dio'ning standart HttpClient'i bo'sh ulanishni 3 s da yopardi va har
// servis o'z Dio'sini qurardi: deyarli har so'rov yangi TCP + TLS
// (bat-dart-dio-new-tls-per-request). Endi isolate'da bitta Dio, bo'sh
// ulanish [kIdleConnectionTimeout] ochiq — bir tick'dagi so'rovlar bitta
// ulanishdan foydalanadi.

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Server (nginx) keep-alive'i 75 s — undan qisqa bo'lishi shart, aks holda
/// server yopayotgan ulanishga so'rov tushadi.
const kIdleConnectionTimeout = Duration(seconds: 45);

const _maxConnectionsPerHost = 6;

Dio createSharedDio(BaseOptions options) => _SharedBackendDio(options);

class _SharedBackendDio extends DioForNative {
  _SharedBackendDio(super.baseOptions) {
    httpClientAdapter = FreshPoolAdapter();
  }

  /// Isolate bo'yicha umumiy: bitta chaqiruvchi `close()` qilsa (masalan iOS
  /// fon sync'i) boshqa servislarning so'rovlari to'xtab qolmasin.
  @override
  void close({bool force = false}) {}
}

/// Ulanishlar havzasi DEVOR soati bo'yicha yangilanadi: oxirgi so'rovdan
/// beri [kIdleConnectionTimeout] o'tgan bo'lsa — yangi HttpClient. Dart
/// taymeri (monoton soat) telefon chuqur uxlaganda yurmaydi: uyg'ongach
/// server yoki operator NAT allaqachon yopgan ulanishga so'rov tushib,
/// xato yoki 30 s kutish bo'lardi.
class FreshPoolAdapter implements HttpClientAdapter {
  /// [newPool] va [clock] — faqat testlar uchun.
  FreshPoolAdapter({
    HttpClientAdapter Function()? newPool,
    DateTime Function()? clock,
  }) : _newPool = newPool ?? _ioPool,
       _clock = clock ?? DateTime.now {
    _pool = _newPool();
  }

  final HttpClientAdapter Function() _newPool;
  final DateTime Function() _clock;
  late HttpClientAdapter _pool;
  DateTime? _lastUse;

  static HttpClientAdapter _ioPool() => IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..idleTimeout = kIdleConnectionTimeout
      ..maxConnectionsPerHost = _maxConnectionsPerHost,
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final now = _clock();
    final lastUse = _lastUse;
    if (lastUse != null &&
        now.difference(lastUse).abs() >= kIdleConnectionTimeout) {
      final stale = _pool;
      _pool = _newPool();
      // Davom etayotgan so'rovlar tugaydi, bo'sh ulanishlar yopiladi.
      stale.close();
    }
    _lastUse = now;
    try {
      return await _pool.fetch(options, requestStream, cancelFuture);
    } finally {
      _lastUse = _clock();
    }
  }

  /// Umumiy — yopilmaydi.
  @override
  void close({bool force = false}) {}
}
