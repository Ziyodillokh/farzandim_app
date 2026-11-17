// ─────────────────────────────────────────────────────────────────────
// ClockSyncInterceptor — HTTP `Date` sarlavhasidan server vaqtini o'rganadi
// ─────────────────────────────────────────────────────────────────────
//
// Umumiy backend Dio'da turadi: har javob (xato javob ham — 401/5xx ham
// `Date` bilan keladi) TrustedClock'ga bitta namuna beradi. Hamma metodlar
// sinxron, try/catch ichida va doim `handler.next` chaqiradi.

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/time/trusted_clock.dart';
import 'package:flutter/foundation.dart';

class ClockSyncInterceptor extends Interceptor {
  static const _watchKey = 'parvoz.clockWatch';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      options.extra[_watchKey] = Stopwatch()..start();
    } on Object catch (e) {
      debugPrint('[clock] so\'rov belgilanmadi: ${e.runtimeType}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _observe(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) _observe(response);
    handler.next(err);
  }

  void _observe(Response<dynamic> response) {
    try {
      final watch = response.requestOptions.extra[_watchKey];
      if (watch is! Stopwatch) return;
      final serverDate = parseHttpDate(response.headers['date']?.first);
      if (serverDate == null) return;
      TrustedClock.recordSample(
        serverDate: serverDate,
        roundTrip: watch.elapsed,
        receivedAt: DateTime.now(),
      );
    } on Object catch (e) {
      debugPrint('[clock] namuna olinmadi: ${e.runtimeType}');
    }
  }
}

const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

final _rfc1123 = RegExp(
  r'^[A-Za-z]{3}, (\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// RFC 1123 (`Sun, 06 Nov 1994 08:49:37 GMT`) → UTC. Boshqa format yoki
/// noto'g'ri qiymat — `null` (dart:io'siz, web'da ham ishlaydi).
DateTime? parseHttpDate(String? value) {
  if (value == null) return null;
  final match = _rfc1123.firstMatch(value.trim());
  if (match == null) return null;
  final month = _months[match.group(2)];
  if (month == null) return null;
  final day = int.parse(match.group(1)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  if (day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60) {
    return null;
  }
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    day,
    hour,
    minute,
    second,
  );
}
