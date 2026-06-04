// ─────────────────────────────────────────────────────────────────────
// DioClient — Backend REST API uchun HTTP client (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// 3 ta interceptor:
//   1. AuthInterceptor — har request'ga Bearer accessToken header
//   2. RefreshInterceptor — 401 javobida /api/auth/refresh + retry
//   3. LoggingInterceptor — debug build'da request/response log
//
// Pairing endpoint (`/auth/child-pair`) auth'siz — interceptor skip qiladi.

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioClientProvider = Provider<Dio>((ref) {
  return createBackendDio(ref.watch(tokenStorageProvider));
});

/// Backend Dio yaratish — auth (Bearer) + refresh (401 → /auth/refresh + retry)
/// interceptorlari bilan. UI isolate (provider) VA background isolate
/// (DeviceInfoService/LocationService) shu funksiyani ishlatadi, shunda
/// 15-daqiqalik access token tugasa avtomatik yangilanadi (heartbeat/location
/// to'xtab qolmaydi). Riverpod'siz, har joyda ishlaydi.
Dio createBackendDio(TokenStorage tokenStorage) {
  final dio = Dio(
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

  dio.interceptors.add(_AuthInterceptor(tokenStorage));
  dio.interceptors.add(
    _RefreshInterceptor(dio: dio, tokenStorage: tokenStorage),
  );
  if (kDebugMode) {
    dio.interceptors.add(_LoggingInterceptor());
  }

  return dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final TokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip: pair (auth'siz) va refresh endpoint'i
    if (options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/child-pair')) {
      handler.next(options);
      return;
    }
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _RefreshInterceptor extends Interceptor {
  _RefreshInterceptor({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;
  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.path.contains('/auth/child-pair') ||
        err.requestOptions.extra['_retried'] == true) {
      handler.next(err);
      return;
    }

    try {
      final newAccess = await _refreshAccessToken();
      if (newAccess == null) {
        handler.next(err);
        return;
      }
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess'
        ..extra['_retried'] = true;
      final response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(null);
        return null;
      }
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data == null) {
        completer.complete(null);
        return null;
      }
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null) {
        completer.complete(null);
        return null;
      }
      await tokenStorage.updateAccessToken(newAccess);
      if (newRefresh != null) {
        await tokenStorage.updateRefreshToken(newRefresh);
      }
      completer.complete(newAccess);
      return newAccess;
    } catch (_) {
      await tokenStorage.clear();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
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
