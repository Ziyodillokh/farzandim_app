// ─────────────────────────────────────────────────────────────────────
// TokenRefresher — 401 dan keyin sessiyani tiklash (bitta akkaunt)
// ─────────────────────────────────────────────────────────────────────
//
// Isolate bo'yicha YAGONA (umumiy backend Dio'ning interceptor'ida): bir
// vaqtda kelgan 401'lar bitta tiklashni kutadi. Tartib:
//   1. Xotira yoki storage'da 401 olgan tokendan YANGIROQ access bo'lsa —
//      refresh'siz shu bilan qayta yuboriladi (boshqa isolate yangilagan).
//   2. Aks holda POST /auth/refresh:
//      • yangi juft → saqlanadi (bitta atomik yozuv);
//      • SESSION_REVOKED / 'Token revoked' / 'User not found or inactive' →
//        tokenlar tozalanadi + SessionEvents.notifyRevoked (sabab bilan);
//      • 'Session rotated' va boshqa 401 → ~1 s kutib storage qayta
//        o'qiladi, yangiroq token bo'lsa bir marta qayta uriniladi.
//        HECH QACHON tozalanmaydi;
//      • tarmoq xatosi / 5xx → 60 s imtiyoz ichida yana 2 marta (javob
//        yo'lda yo'qolgan bo'lsa ham server oldingi tokenni joriy juftga
//        almashtiradi); bo'lmasa — hech narsa o'zgarmaydi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_pair.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/refresh_outcome.dart';
import 'package:flutter/foundation.dart';

class TokenRefresher {
  TokenRefresher({required this.storage, required this.dio});

  final TokenStorage storage;

  /// Refresh so'rovi shu (umumiy) Dio orqali — ulanish qayta ishlatiladi.
  final Dio dio;

  /// 'Session rotated' dan keyin storage qayta o'qilishidan oldingi kutish.
  @visibleForTesting
  static Duration rotatedRetryDelay = const Duration(seconds: 1);

  /// Tarmoq xatosi / 5xx dan keyingi qayta urinishlar (60 s imtiyoz ichida).
  @visibleForTesting
  static List<Duration> networkRetryDelays = const [
    Duration(seconds: 2),
    Duration(seconds: 6),
  ];

  /// Shu muddat ichida berilgan token bilan ham 401 bo'lsa — sabab muddat
  /// emas: qayta refresh qilinmaydi (rotatsiya bo'roni bo'lmasin).
  static const refreshCooldown = Duration(seconds: 30);

  Future<String?>? _inFlight;
  String? _lastIssuedAccess;
  Stopwatch? _sinceIssued;

  /// [failedToken] bilan 401 olgan so'rov qayta yuborilishi mumkin bo'lgan
  /// access token; `null` — tiklab bo'lmadi (so'rov 401 bilan tugaydi).
  /// Hech qachon xato tashlamaydi.
  Future<String?> recover(String? failedToken) {
    final known = storage.cachedPair?.accessToken;
    if (known != null && isLaterToken(known, failedToken)) {
      return Future.value(known);
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final run = _recover(failedToken);
    _inFlight = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_inFlight, run)) _inFlight = null;
      }),
    );
    return run;
  }

  Future<String?> _recover(String? failedToken) async {
    try {
      // Boshqa isolate allaqachon yangilagan bo'lishi mumkin.
      await storage.reload();
      final best = storage.cachedPair;
      if (best != null && isLaterToken(best.accessToken, failedToken)) {
        return best.accessToken;
      }
      if (_justIssued(failedToken)) return null;
      // Refresh token yo'q yoki o'qilmadi — NOMA'LUM: hech narsa o'chirilmaydi.
      if (best == null || !best.canRefresh) return null;
      return await _refreshWith(
        best.refreshToken,
        failedToken,
        retryRotated: true,
      );
    } on Object catch (e) {
      debugPrint('[auth] tiklash xatosi: ${e.runtimeType}');
      return null;
    }
  }

  bool _justIssued(String? failedToken) {
    final watch = _sinceIssued;
    return failedToken != null &&
        failedToken == _lastIssuedAccess &&
        watch != null &&
        watch.elapsed < refreshCooldown;
  }

  Future<String?> _refreshWith(
    String refreshToken,
    String? failedToken, {
    required bool retryRotated,
  }) async {
    final generation = storage.generation;
    final outcome = await _post(refreshToken);
    switch (outcome) {
      case RefreshIssued(:final pair):
        return _keep(pair, generation);
      case RefreshRevoked(:final reason):
        return _revoke(refreshToken, failedToken, reason);
      case RefreshRejected():
        return retryRotated
            ? _retryAfterRotation(refreshToken, failedToken)
            : null;
      case RefreshUnavailable():
        return null;
    }
  }

  Future<String?> _keep(TokenPair pair, int generation) async {
    if (storage.generation != generation) {
      // Javob kutilayotganda shu isolate qayta kirdi yoki chiqdi — eski
      // sessiya javobi yangi holat ustiga yozilmaydi.
      final current = storage.cachedPair?.accessToken;
      return current == null || current.isEmpty ? null : current;
    }
    _lastIssuedAccess = pair.accessToken;
    _sinceIssued = Stopwatch()..start();
    // Xotira saveTokens ichida darhol yangilanadi; storage yozuvi bir marta
    // qayta uriniladi (Keystore vaqtincha xatosi).
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await storage.saveTokens(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
        );
        break;
      } on Object catch (e) {
        debugPrint('[auth] yangi tokenlar saqlanmadi: ${e.runtimeType}');
      }
    }
    return pair.accessToken;
  }

  Future<String?> _revoke(
    String sentRefresh,
    String? failedToken,
    String? reason,
  ) async {
    var cleared = true;
    try {
      cleared = await storage.clearIfCurrent(sentRefresh);
    } on Object catch (e) {
      debugPrint('[auth] tokenlar tozalanmadi: ${e.runtimeType}');
    }
    if (!cleared) {
      // Shu orada yangi sessiya yozilgan (qayta kirish / boshqa isolate).
      final known = storage.cachedPair?.accessToken;
      return known != null && isLaterToken(known, failedToken) ? known : null;
    }
    SessionEvents.notifyRevoked(reason: reason, scope: storage.keyPrefix);
    return null;
  }

  Future<String?> _retryAfterRotation(
    String sentRefresh,
    String? failedToken,
  ) async {
    await Future<void>.delayed(rotatedRetryDelay);
    await storage.reload();
    final best = storage.cachedPair;
    if (best == null) return null;
    if (isLaterToken(best.accessToken, failedToken)) return best.accessToken;
    if (best.canRefresh && best.refreshToken != sentRefresh) {
      return _refreshWith(best.refreshToken, failedToken, retryRotated: false);
    }
    return null;
  }

  Future<RefreshOutcome> _post(String refreshToken) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await dio.post<Object?>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        return issuedFrom(response.data, sentRefreshToken: refreshToken);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          return classifyRefreshRejection(e.response?.data);
        }
        if (!_isRetriable(e) || attempt >= networkRetryDelays.length) {
          return const RefreshUnavailable();
        }
        await Future<void>.delayed(networkRetryDelays[attempt]);
      }
    }
  }

  static bool _isRetriable(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) return status >= 500;
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }
}
