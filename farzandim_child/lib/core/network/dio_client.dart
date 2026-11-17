// ─────────────────────────────────────────────────────────────────────
// DioClient — Backend REST API uchun HTTP client (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Interceptor'lar (tartibda):
//   1. ClockSyncInterceptor — `Date` sarlavhasidan server vaqti (TrustedClock)
//   2. AuthHeaderInterceptor — har request'ga Bearer accessToken (xotiradan)
//   3. SessionRefreshInterceptor — 401 → tiklash/refresh → bir marta retry
//   4. LoggingInterceptor — debug build'da request/response log
//
// 1.0.20: `createBackendDio` har chaqiruvda YANGI Dio qurmaydi — isolate
// bo'yicha akkaunt (token prefiksi) uchun BITTA umumiy Dio qaytaradi:
//   • refresh isolate ichida bitta (single-flight) — avval ~10 ta Dio bir
//     vaqtda bitta refresh token bilan /auth/refresh qilib sessiyani
//     o'chirardi (fn-refresh-race-logout);
//   • TLS ulanishlari qayta ishlatiladi (shared_dio_io.dart).
//
// Pairing endpoint (`/auth/child-pair`) auth'siz — interceptor skip qiladi.

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/auth_interceptors.dart';
import 'package:farzandim_child/core/network/clock_sync_interceptor.dart';
import 'package:farzandim_child/core/network/shared_dio_stub.dart'
    if (dart.library.io) 'package:farzandim_child/core/network/shared_dio_io.dart';
import 'package:farzandim_child/core/network/token_refresher.dart';
import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioClientProvider = Provider<Dio>((ref) {
  return createBackendDio(ref.watch(tokenStorageProvider));
});

/// Isolate bo'yicha umumiy Dio'lar: kalit — baseUrl + akkaunt (token
/// prefiksi). Mehmon akkaunt o'z tokeni bilan alohida Dio oladi.
final Map<String, Dio> _sharedDios = {};

/// Backend Dio — auth (Bearer) + refresh (401 → tiklash + retry). UI isolate
/// (provider) VA background isolate (servislar) shu funksiyani ishlatadi.
/// Shu isolate va akkaunt uchun HAR DOIM bir xil nusxa qaytadi; uning
/// `close()` i hech narsa qilmaydi (boshqa servislar ham ishlatadi).
Dio createBackendDio(TokenStorage tokenStorage) {
  unawaited(TrustedClock.ensureLoaded());
  final key = '${EnvConfig.apiUrl}|${tokenStorage.keyPrefix}';
  return _sharedDios.putIfAbsent(key, () => buildBackendDio(tokenStorage));
}

/// Umumiy ro'yxatga QO'SHILMAYDIGAN yangi backend Dio — testlar ikki
/// isolate'ni (har biri o'z refresh holati bilan) taqlid qilishi uchun.
@visibleForTesting
Dio buildBackendDio(TokenStorage tokenStorage) {
  final dio = createSharedDio(
    BaseOptions(
      baseUrl: EnvConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.interceptors.addAll([
    ClockSyncInterceptor(),
    AuthHeaderInterceptor(tokenStorage),
    SessionRefreshInterceptor(
      dio: dio,
      refresher: TokenRefresher(storage: tokenStorage, dio: dio),
    ),
    if (kDebugMode) _LoggingInterceptor(),
  ]);
  return dio;
}

/// Testlar orasida umumiy Dio'larni unutish.
@visibleForTesting
void resetSharedBackendDios() => _sharedDios.clear();

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
      '→ ${options.method} ${options.uri}'
      '${options.headers['Authorization'] != null ? ' [auth]' : ''}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '✗ ${err.response?.statusCode ?? 'NO_RES'} '
      '${err.requestOptions.uri} — ${err.message}',
    );
    handler.next(err);
  }
}
