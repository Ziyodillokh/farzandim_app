import 'dart:math';

import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import '../logging/app_logger.dart';
import '../logging/log_sanitizer.dart';
import '../ux/app_loading.dart';
import 'admin_auth_refresh.dart';
import 'admin_session.dart';
import 'dio_error_mapper.dart';
import 'token_refresh_coordinator.dart';
import 'web_credentials_stub.dart'
    if (dart.library.html) 'web_credentials_web.dart';

Future<void> _logDioError(DioException error) async {
  final uri = error.requestOptions.uri;
  final status = error.response?.statusCode;
  final mapped = mapDioException(error);
  AppLogger.error(
    'DioException $status ${LogSanitizer.stringForLog(uri.toString())}: ${mapped.message}',
    error: error,
    stackTrace: error.stackTrace,
  );
  final body = error.response?.data;
  if (body != null) {
    AppLogger.debug('Response body: ${LogSanitizer.valueForLog(body)}');
  }
}

Dio _plainDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnvironment.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  applyWebCredentials(dio); // H7 — web'da HttpOnly cookie yuborish uchun
  return dio;
}

String _newRequestId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';

bool _isAnonymousAuthPath(String path) {
  final p = path.toLowerCase();
  return p.contains('/admin/auth/login') ||
      p.contains('/admin/auth/refresh') ||
      p.contains('/admin/auth/2fa/verify');
}

class ApiClient {
  ApiClient({Dio? client, Dio? refreshDio}) : dio = client ?? _buildDio() {
    _plain = refreshDio ?? _plainDio();
    dio.interceptors.add(_AdminAuthInterceptor(dio: dio, plainDio: _plain));
  }

  final Dio dio;
  late final Dio _plain;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnvironment.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    applyWebCredentials(dio); // H7 — web'da HttpOnly cookie yuborish uchun
    return dio;
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e, st) {
      AppLogger.error('GET $path failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    AppLoading.instance.begin();
    try {
      return await dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e, st) {
      AppLogger.error('POST $path failed', error: e, stackTrace: st);
      rethrow;
    } finally {
      AppLoading.instance.end();
    }
  }

  /// Long-running uploads (multipart): avoids global loading overlay flicker.
  Future<Response<dynamic>> postWithoutGlobalLoading(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e, st) {
      AppLogger.error('POST $path failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    AppLoading.instance.begin();
    try {
      return await dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e, st) {
      AppLogger.error('PATCH $path failed', error: e, stackTrace: st);
      rethrow;
    } finally {
      AppLoading.instance.end();
    }
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    AppLoading.instance.begin();
    try {
      return await dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e, st) {
      AppLogger.error('DELETE $path failed', error: e, stackTrace: st);
      rethrow;
    } finally {
      AppLoading.instance.end();
    }
  }
}

final class _AdminAuthInterceptor extends QueuedInterceptor {
  _AdminAuthInterceptor({required this.dio, required this.plainDio});

  final Dio dio;
  final Dio plainDio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final rid = _newRequestId();
    options.extra['requestId'] = rid;

    (() async {
      try {
        if (!_isAnonymousAuthPath(options.path)) {
          if (AdminSession.needsProactiveRefresh) {
            await TokenRefreshCoordinator.runLocked(
              () => performTokenRefresh(plainDio),
            );
          }
          final token = AdminSession.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        AppLogger.apiRequest(
          rid,
          options.method,
          options.uri,
          body: options.data,
        );
        handler.next(options);
      } catch (e, st) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: e,
            stackTrace: st,
            type: DioExceptionType.unknown,
          ),
        );
      }
    })();
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final rid = response.requestOptions.extra['requestId'] as String? ?? '-';
    AppLogger.apiResponse(
      rid,
      response.statusCode,
      response.requestOptions.uri,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    (() async {
      await _logDioError(err);

      final request = err.requestOptions;
      final status = err.response?.statusCode;
      final retried = request.extra['__retried'] == true;

      if (status == 401 &&
          !retried &&
          !_isAnonymousAuthPath(request.path) &&
          AdminSession.hasRefreshToken) {
        final newAccess = await TokenRefreshCoordinator.runLocked(
          () => performTokenRefresh(plainDio),
        );
        if (newAccess != null && newAccess.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $newAccess';
          request.extra['__retried'] = true;
          try {
            final clone = await dio.fetch<dynamic>(request);
            handler.resolve(clone);
            return;
          } on DioException catch (e, st) {
            await _logDioError(e);
            AppLogger.error(
              'Retry after refresh failed',
              error: e,
              stackTrace: st,
            );
            if (e.response?.statusCode == 401) {
              await AdminSession.clear(cause: SessionClearCause.sessionExpired);
            }
            handler.next(e);
            return;
          }
        }
        handler.next(err);
        return;
      }

      if (status == 401 && !_isAnonymousAuthPath(request.path)) {
        if (retried || !AdminSession.hasRefreshToken) {
          await AdminSession.clear(cause: SessionClearCause.sessionExpired);
        }
      }
      handler.next(err);
    })();
  }
}
