import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/app_environment.dart';
import 'log_sanitizer.dart';

/// Centralized logging — use instead of [print].
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: false,
      printEmojis: false,
    ),
    level: AppEnvironment.isDebug && !kReleaseMode ? Level.debug : Level.warning,
  );

  static void info(String message, [Object? error]) {
    _logger.i('${AppEnvironment.logLabel} $message', error: error);
  }

  static void warning(String message, [Object? error]) {
    _logger.w('${AppEnvironment.logLabel} $message', error: error);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(
      '${AppEnvironment.logLabel} $message',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void debug(String message, [Object? error]) {
    if (kReleaseMode || !AppEnvironment.isDebug) {
      return;
    }
    _logger.d('${AppEnvironment.logLabel} $message', error: error);
  }

  static void apiRequest(String requestId, String method, Uri uri, {Object? body}) {
    if (kReleaseMode) {
      return;
    }
    final safeUri = LogSanitizer.stringForLog(uri.toString());
    final b = body != null ? LogSanitizer.valueForLog(body) : null;
    _logger.d('[API] [REQUEST] [$requestId] $method $safeUri ${b != null ? 'body=$b' : ''}');
  }

  static void apiResponse(String requestId, int? status, Uri uri) {
    if (kReleaseMode) {
      return;
    }
    final safe = LogSanitizer.stringForLog(uri.toString());
    _logger.d('[API] [RESPONSE] [$requestId] $status $safe');
  }
}
