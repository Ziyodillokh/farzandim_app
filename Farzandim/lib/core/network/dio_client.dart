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

/// API base URL — default `EnvConfig.apiUrl` (mobil/production). Web preview
/// uni override qiladi va joriy brauzer host'idan oladi (IP o'zgarsa ham
/// qayta build shart emas).
final apiBaseUrlProvider = Provider<String>((_) => EnvConfig.apiUrl);

/// Singleton Dio provider — barcha repository'lar shundan o'qiydi.
final dioClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: ref.watch(apiBaseUrlProvider),
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
  // Tarif 403 — qulflangan funksiyani "yuksalting" oynasiga ulaydi.
  dio.interceptors.add(_EntitlementInterceptor());
  if (kDebugMode) {
    dio.interceptors.add(_LoggingInterceptor());
  }

  return dio;
});

// ─── 1. AuthInterceptor ────────────────────────────────────────────────
// Har request'ga `Authorization: Bearer <token>` header qo'shadi.
// Token yo'q bo'lsa header'siz ketadi — public endpoint'lar uchun OK.
// Xotira xato bersa so'rov OSILIB QOLMAYDI (handler.next doim chaqiriladi).
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
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Token o'qilmadi — header'siz ketadi; 401 bo'lsa refresh qayta urinadi.
    }
    handler.next(options);
  }
}

/// `extra` belgisi: refresh tarmoq/server xatosi sabab bajarilmadi — 401
/// sessiya tugaganini ANGLATMAYDI (chaqiruvchi foydalanuvchini chiqarmasin).
const kAuthUnavailableExtra = '_authUnavailable';

/// `extra` belgisi: server sessiyani ANIQ bekor qildi (refresh 401) —
/// tokenlar o'chirildi va [onSessionExpired] chaqirildi.
const kAuthRevokedExtra = '_authRevoked';

/// Refresh natijasi.
enum _RefreshResult { refreshed, revoked, unavailable }

/// Refresh kutish vaqtlari (testlarda nolga tushiriladi).
class RefreshTuning {
  RefreshTuning._();

  /// Tarmoq/server xatosida qayta urinishlar — server imtiyozi (60 s) ichida.
  @visibleForTesting
  static List<Duration> retryDelays = const [
    Duration(seconds: 2),
    Duration(seconds: 6),
  ];

  /// "Session rotated" dan keyin boshqa yozuv tugashini kutish.
  @visibleForTesting
  static Duration rotatedRecheckDelay = const Duration(seconds: 1);

  /// Bitta refresh so'rovi uchun yuborish/qabul timeout'i. Server javobni
  /// yo'qotgan holatda ham barcha urinishlar (connect 10 s bilan) birinchi
  /// rotatsiyadan keyingi 60 s imtiyoz ichida serverga yetadi.
  static const requestTimeout = Duration(seconds: 12);
}

// ─── 2. RefreshInterceptor ─────────────────────────────────────────────
// 401 ushlanganda /api/auth/refresh chaqiradi, yangi token oladi va
// asl request'ni retry qiladi. Concurrent 401'lar uchun bitta refresh.
//
// Tokenlar FAQAT server sessiyani aniq bekor qilganda o'chiriladi
// (SESSION_REVOKED, "Token revoked", "Invalid refresh token", "User not found
// or inactive"). Tarmoq uzilishi, 5xx yoki javob yo'qolishi foydalanuvchini
// login'ga chiqarmaydi: refresh serverning 60 s imtiyozi ichida qayta
// uriniladi. "Session rotated" — avval xotirada yangiroq token bormi
// tekshiriladi (boshqa so'rov allaqachon yangilagan bo'lishi mumkin).
class _RefreshInterceptor extends Interceptor {
  _RefreshInterceptor({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

  // Refresh in-flight'ni nazorat qiladi (race condition oldini olish).
  Completer<_RefreshResult>? _refreshCompleter;

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
      // Boshqa so'rov tokenni allaqachon yangilagan bo'lsa — refresh'siz.
      final used = _bearerOf(err.requestOptions);
      final current = await tokenStorage.readAccessToken();
      if (current != null && current.isNotEmpty && current != used) {
        handler.resolve(await _retry(err.requestOptions, current));
        return;
      }

      final result = await _refresh();
      if (result != _RefreshResult.refreshed) {
        final flag = result == _RefreshResult.revoked
            ? kAuthRevokedExtra
            : kAuthUnavailableExtra;
        err.requestOptions.extra[flag] = true;
        handler.next(err);
        return;
      }
      final newAccess = await tokenStorage.readAccessToken();
      if (newAccess == null || newAccess.isEmpty) {
        handler.next(err);
        return;
      }
      handler.resolve(await _retry(err.requestOptions, newAccess));
    } on DioException catch (e) {
      // Takroriy so'rov xatosi o'z zanjiridan allaqachon o'tgan — keyingi
      // interceptor'lar (tarif oynasi, log) ikkinchi marta ishlamasin.
      handler.reject(e);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    final retryOptions = options
      ..headers['Authorization'] = 'Bearer $token'
      ..extra['_retried'] = true;
    return dio.fetch<dynamic>(retryOptions);
  }

  static String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  /// Concurrent 401'lar bir vaqtda refresh chaqirmasligi uchun
  /// Completer orqali ulashilgan future.
  Future<_RefreshResult> _refresh() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;
    final completer = Completer<_RefreshResult>();
    _refreshCompleter = completer;
    _doRefresh()
        .then(
          completer.complete,
          onError: (_) {
            completer.complete(_RefreshResult.unavailable);
          },
        )
        .whenComplete(() => _refreshCompleter = null);
    return completer.future;
  }

  Future<_RefreshResult> _doRefresh() async {
    var stored = await tokenStorage.readRefreshToken();
    if (stored == null || stored.isEmpty) {
      // Kesh bo'sh — xotiradan qayta o'qiymiz; baribir yo'q bo'lsa bu
      // "chiqilgan" EMAS (xotira xatosi bo'lishi mumkin) — refresh yo'q.
      await tokenStorage.reload();
      stored = await tokenStorage.readRefreshToken();
      if (stored == null || stored.isEmpty) {
        return _RefreshResult.unavailable;
      }
    }
    var refreshToken = stored;

    var attempt = 0;
    var triedNewer = false;
    while (true) {
      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(
            extra: {'_skipAuth': true},
            sendTimeout: RefreshTuning.requestTimeout,
            receiveTimeout: RefreshTuning.requestTimeout,
          ),
        );
        final data = response.data;
        final newAccess = data?['accessToken'] as String?;
        if (newAccess == null || newAccess.isEmpty) {
          return _RefreshResult.unavailable;
        }
        if (await _isSuperseded(refreshToken)) return _supersededResult();
        await tokenStorage.updateTokens(
          accessToken: newAccess,
          refreshToken: data?['refreshToken'] as String?,
        );
        return _RefreshResult.refreshed;
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        final transient =
            code == null || code >= 500 || code == 408 || code == 429;
        if (transient) {
          // Javob yo'qolgan bo'lsa server allaqachon rotatsiya qilgan bo'lishi
          // mumkin — imtiyoz (60 s) ichida qayta urinish joriy juftni beradi.
          final delays = RefreshTuning.retryDelays;
          if (attempt >= delays.length) return _RefreshResult.unavailable;
          await Future<void>.delayed(delays[attempt]);
          attempt++;
          continue;
        }
        // Backend /auth/refresh faqat 401 bilan rad etadi; 400/403 kabi
        // javoblar proksi/infratuzilmadan — sessiya holati noma'lum.
        if (code != 401) return _RefreshResult.unavailable;

        if (_isRotated(e.response?.data) && !triedNewer) {
          // Boshqa yangilash (shu ilovada) yangi juftni yozayotgan bo'lishi
          // mumkin — biroz kutib xotiradan o'qiymiz.
          triedNewer = true;
          await Future<void>.delayed(RefreshTuning.rotatedRecheckDelay);
          await tokenStorage.reload();
          final newer = await tokenStorage.readRefreshToken();
          if (newer != null && newer.isNotEmpty && newer != refreshToken) {
            refreshToken = newer;
            continue;
          }
        }
        if (await _isSuperseded(refreshToken)) return _supersededResult();
        // Sessiya haqiqatan tugagan (bekor qilingan, muddati o'tgan yoki
        // rotatsiya imtiyozdan keyin) — login.
        try {
          await tokenStorage.clear();
        } finally {
          onSessionExpired?.call();
        }
        return _RefreshResult.revoked;
      }
    }
  }

  /// Refresh davomida (kutish, qayta urinish) xotiradagi token almashgan:
  /// foydalanuvchi chiqib-kirgan yoki boshqa yozuv yangilagan — bu eski
  /// natija yangi sessiyani o'chirmasin va ustiga yozilmasin.
  Future<bool> _isSuperseded(String flightToken) async =>
      await tokenStorage.readRefreshToken() != flightToken;

  Future<_RefreshResult> _supersededResult() async {
    final current = await tokenStorage.readRefreshToken();
    return current != null && current.isNotEmpty
        ? _RefreshResult.refreshed
        : _RefreshResult.unavailable;
  }

  static bool _isRotated(Object? data) =>
      data is Map && data['message'] == 'Session rotated';
}

/// Sessiya tugaganda (refresh token bekor — 401/403) chaqiriladigan global
/// callback. `BackendAuthNotifier` konstruktorda o'rnatadi: state'ni
/// `AuthAnonymous`ga o'tkazadi → router login ekraniga redirect qiladi.
/// Callback'siz foydalanuvchi "zombi" holatda qolardi (UI ochiq, barcha
/// so'rovlar jim 401, hech qanday xabar yo'q).
void Function()? onSessionExpired;

/// Tarif funksiyasi qulflanganda (403 `FEATURE_NOT_IN_PLAN` yoki
/// `CHILD_LIMIT_REACHED`) chaqiriladigan global callback. `app.dart` uni
/// "Tarifni yuksalting" oynasini ko'rsatishga ulaydi. Backend guard bergan
/// har qanday qulflangan funksiya SHU orqali bitta joyda ishlov oladi.
void Function(String? feature, String? message, String? requiredTier)?
onFeatureLocked;

// ─── EntitlementInterceptor ────────────────────────────────────────────
// Backend `@RequireFeature` guard 403 (`code: FEATURE_NOT_IN_PLAN`) yoki
// bola-limit (`CHILD_LIMIT_REACHED`) qaytarsa — `onFeatureLocked` chaqiradi
// (foydalanuvchi funksiyani bosganda "yuksalting" oynasi). LEKIN passiv/fon
// so'rovlar `extra: {'_passive': true}` bilan belgilanadi; ular 403 qaytarsa
// modal CHIQMAYDI — aks holda dashboard'dagi haftalik qadamlar `/weekly-report`
// auto-fetch'i 403 bo'lib, ilovaga kirgach oyna o'zidan-o'zi ochilib qolardi.
// Xatoni BLOKLAMAYDI (handler.next) — chaqiruvchi kod ham o'z holicha ishlaydi.
class _EntitlementInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 &&
        err.requestOptions.extra['_passive'] != true) {
      final data = err.response?.data;
      if (data is Map) {
        final code = data['code'] as String?;
        if (code == 'FEATURE_NOT_IN_PLAN' || code == 'CHILD_LIMIT_REACHED') {
          onFeatureLocked?.call(
            data['feature'] as String?,
            data['message'] as String?,
            data['requiredTier'] as String?,
          );
        }
      }
    }
    handler.next(err);
  }
}

// ─── 3. LoggingInterceptor ─────────────────────────────────────────────
// Debug build'da request/response log qiladi. Production'da o'chiriladi
// (`kDebugMode` flag bilan).
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
