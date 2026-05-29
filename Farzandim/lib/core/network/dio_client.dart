// ─────────────────────────────────────────────────────────────────────
// DioClient — Backend REST API uchun HTTP client (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// 3 ta interceptor:
//   1. AuthInterceptor — har request'ga Bearer accessToken header
//   2. RefreshInterceptor — 401 javobida /api/auth/refresh + retry
//   3. LoggingInterceptor — debug build'da request/response log
//
// Foydalanish:
//   final dio = ref.read(dioClientProvider);
//   final response = await dio.get('/users/me');
//
// BaseURL allaqachon EnvConfig.apiUrl'dan o'rnatildi — endpoint'larda
// faqat path beriladi (`/users/me`, `/children`, `/location/history`).
//
// Refresh strategiyasi:
//   - 401 javob kelganda RefreshInterceptor ushlaydi
//   - /api/auth/refresh chaqiradi (yangi access + refresh token)
//   - Asl request'ni yangi token bilan retry qiladi
//   - Refresh ham 401 bersa: token storage tozalanadi (logout)
//
// Concurrency:
//   - Birinchi 401'ni Lock orqali boshqaramiz — 5 parallel request
//     bir vaqtda 5 ta refresh ishga tushirmasligi uchun
//   - Refresh in-flight: keyingi 401'lar shu Future'ni kutadi

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton Dio provider — barcha repository'lar shundan o'qiydi.
final dioClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
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
});

// ─── 1. AuthInterceptor ────────────────────────────────────────────────
// Har request'ga `Authorization: Bearer <token>` header qo'shadi.
// Token yo'q bo'lsa header'siz ketadi — public endpoint'lar uchun OK.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);

  final TokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip refresh endpoint'i — uning o'zi refresh token ishlatadi
    if (options.path.contains('/auth/refresh')) {
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

// ─── 2. RefreshInterceptor ─────────────────────────────────────────────
// 401 ushlanganda /api/auth/refresh chaqiradi, yangi token oladi va
// asl request'ni retry qiladi. Concurrent 401'lar uchun bitta refresh.
class _RefreshInterceptor extends Interceptor {
  _RefreshInterceptor({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

  // Refresh in-flight'ni nazorat qiladi (race condition oldini olish).
  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 401 emas yoki refresh endpoint'ining o'zi xato bersa — pass.
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.extra['_retried'] == true) {
      handler.next(err);
      return;
    }

    try {
      final newAccess = await _refreshAccessToken();
      if (newAccess == null) {
        // Refresh yo'q yoki muvaffaqiyatsiz — original xatoni qaytarish
        handler.next(err);
        return;
      }

      // Asl request'ni yangi token bilan retry qilamiz.
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess'
        ..extra['_retried'] = true;

      final response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  /// Concurrent 401'lar bir vaqtda refresh chaqirmasligi uchun
  /// Completer orqali ulashilgan future.
  Future<String?> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      // Boshqa request allaqachon refresh qilmoqda — uni kutamiz
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(null);
        return null;
      }

      // Refresh request — interceptor chiqib ketmasligi uchun extra flag
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'_skipAuth': true}),
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
      // Refresh ham fail — logout
      await tokenStorage.clear();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}

// ─── 3. LoggingInterceptor ─────────────────────────────────────────────
// Debug build'da request/response log qiladi. Production'da o'chiriladi
// (`kDebugMode` flag bilan).
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
    debugPrint(
      '← ${response.statusCode} ${response.requestOptions.uri}',
    );
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
