// ─────────────────────────────────────────────────────────────────────
// Auth interceptor'lari — Bearer token va 401 → tiklash + qayta yuborish
// ─────────────────────────────────────────────────────────────────────
//
// Dio 5 async interceptor'ning qaytargan Future'ini kutmaydi — faqat
// handler'ni. Shu sabab har tana try/catch ichida va handler DOIM aniq bir
// marta chaqiriladi: token o'qishdagi xato so'rovni abadiy osiltirib
// qo'ymaydi (rob-dart-onstart-hang-interceptor).

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/token_refresher.dart';
import 'package:flutter/foundation.dart';

const _retriedKey = '_retried';
const _authHeader = 'Authorization';

/// Token kerak bo'lmagan yo'llar (juftlash va refresh'ning o'zi).
bool skipsAuth(String path) =>
    path.contains('/auth/refresh') || path.contains('/auth/child-pair');

/// So'rovdagi Bearer token (bo'lmasa `null`).
String? bearerTokenOf(RequestOptions options) {
  final value = options.headers[_authHeader];
  if (value is! String || !value.startsWith('Bearer ')) return null;
  final token = value.substring('Bearer '.length);
  return token.isEmpty ? null : token;
}

/// Har so'rovga xotiradagi access token (storage — faqat birinchi marta).
class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(this._storage);

  final TokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final isRetry =
          options.extra[_retriedKey] == true &&
          options.headers[_authHeader] != null;
      if (!skipsAuth(options.path) && !isRetry) {
        final token = await _storage.accessTokenForRequest();
        if (token != null) options.headers[_authHeader] = 'Bearer $token';
      }
    } on Object catch (e) {
      // Token o'qilmadi — so'rov tokensiz ketadi (401 → tiklash).
      debugPrint('[auth] token qo\'yilmadi: ${e.runtimeType}');
    }
    handler.next(options);
  }
}

/// 401 → [TokenRefresher.recover] → yangiroq token bilan BIR marta qayta.
class SessionRefreshInterceptor extends Interceptor {
  SessionRefreshInterceptor({
    required Dio dio,
    required TokenRefresher refresher,
  }) : _dio = dio,
       _refresher = refresher;

  final Dio _dio;
  final TokenRefresher _refresher;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    var failure = err;
    Response<dynamic>? recovered;
    try {
      if (_isRecoverable(err)) {
        recovered = await _recoverAndRetry(err.requestOptions);
      }
    } on DioException catch (e) {
      // Qayta yuborish ham yiqildi — uning xatosi (masalan 500) aniqroq.
      failure = e;
    } on Object catch (e) {
      debugPrint('[auth] 401 tiklanmadi: ${e.runtimeType}');
    }
    if (recovered != null) {
      handler.resolve(recovered);
    } else {
      handler.next(failure);
    }
  }

  /// Ko'pi bilan ikki bosqich: boshqa isolate yozgan (storage/xotira) token
  /// ham eskirgan bo'lishi mumkin — u ham 401 olsa, shu token bilan yana bir
  /// marta tiklanadi (endi refresh bo'ladi). Yangi berilgan token 401 olsa
  /// TokenRefresher qayta refresh qilmaydi (cooldown) — aylanish yo'q.
  Future<Response<dynamic>?> _recoverAndRetry(RequestOptions options) async {
    var failed = bearerTokenOf(options);
    for (var round = 0; round < 2; round++) {
      final token = await _refresher.recover(failed);
      if (token == null || token == failed) return null;
      try {
        return await _dio.fetch<dynamic>(_retryOf(options, token));
      } on DioException catch (e) {
        if (round > 0 || e.response?.statusCode != 401) rethrow;
        failed = token;
      }
    }
    return null;
  }

  static bool _isRecoverable(DioException err) {
    final options = err.requestOptions;
    return err.response?.statusCode == 401 &&
        !skipsAuth(options.path) &&
        options.extra[_retriedKey] != true;
  }

  static RequestOptions _retryOf(RequestOptions options, String token) {
    final data = options.data;
    return options.copyWith(
      // FormData bir marta o'qiladi — qayta yuborish uchun nusxa.
      data: data is FormData ? data.clone() : data,
      headers: {...options.headers, _authHeader: 'Bearer $token'},
      extra: {...options.extra, _retriedKey: true},
    );
  }
}
