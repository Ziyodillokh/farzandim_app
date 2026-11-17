// RefreshInterceptor — 401 da token yangilash: faqat server sessiyani aniq
// bekor qilganda chiqariladi; tarmoq/server xatosi va "Session rotated"
// poygasi foydalanuvchini login'ga chiqarmaydi.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/memory_token_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryBackend backend;
  late TokenStorage storage;
  late ProviderContainer container;
  late int expiredCalls;
  final defaultRetryDelays = RefreshTuning.retryDelays;
  final defaultRotatedDelay = RefreshTuning.rotatedRecheckDelay;

  /// Server holati: amal qiladigan access va refresh tokenlar.
  late Set<String> validAccess;

  Dio dioWith(FakeReply Function(RequestOptions o) handler) {
    return container.read(dioClientProvider)
      ..httpClientAdapter = FakeHttpAdapter(handler);
  }

  String? bearer(RequestOptions o) =>
      (o.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');

  bool isRefresh(RequestOptions o) => o.path.contains('/auth/refresh');

  String? refreshArg(RequestOptions o) =>
      (o.data as Map<String, dynamic>)['refreshToken'] as String?;

  /// Oddiy API: faqat amal qiladigan access bilan 200.
  FakeReply api(RequestOptions o) => validAccess.contains(bearer(o))
      ? const FakeReply(200, {'id': 'u1'})
      : const FakeReply(401, {'message': 'Unauthorized'});

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TokenStorage.resetCacheForTest();
    RefreshTuning.retryDelays = const [Duration.zero, Duration.zero];
    RefreshTuning.rotatedRecheckDelay = Duration.zero;
    backend = MemoryBackend();
    storage = TokenStorage(backend: backend);
    await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
    validAccess = {};
    expiredCalls = 0;
    onSessionExpired = () => expiredCalls++;
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiBaseUrlProvider.overrideWithValue('https://api.test/api'),
      ],
    );
  });

  tearDown(() {
    onSessionExpired = null;
    onFeatureLocked = null;
    RefreshTuning.retryDelays = defaultRetryDelays;
    RefreshTuning.rotatedRecheckDelay = defaultRotatedDelay;
    container.dispose();
  });

  Future<DioException?> failureOf(Future<Object?> request) =>
      request.then((_) => null, onError: (Object e) => e as DioException);

  test('401 → refresh → asl so`rov yangi token bilan takrorlanadi', () async {
    validAccess = {'A2'};
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      expect(refreshArg(o), 'R1');
      return const FakeReply(200, {'accessToken': 'A2', 'refreshToken': 'R2'});
    });

    final res = await dio.get<Map<String, dynamic>>('/users/me');

    expect(res.data, {'id': 'u1'});
    expect(await storage.readAccessToken(), 'A2');
    expect(await storage.readRefreshToken(), 'R2');
    final pair = jsonDecode(backend.store['jwt_tokens_v2']!) as Map;
    expect(pair, {'a': 'A2', 'r': 'R2'});
    expect(expiredCalls, 0);
  });

  test('parallel 401 lar bitta refresh bilan yangilanadi', () async {
    validAccess = {'A2'};
    var refreshes = 0;
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      refreshes++;
      return const FakeReply(200, {'accessToken': 'A2', 'refreshToken': 'R2'});
    });

    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/users/me'),
      dio.get<Map<String, dynamic>>('/children'),
      dio.get<Map<String, dynamic>>('/notifications'),
    ]);

    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(refreshes, 1);
  });

  test('xotirada yangiroq access bo`lsa refresh chaqirilmaydi', () async {
    validAccess = {'A2'};
    var refreshes = 0;
    final dio = dioWith((o) {
      if (isRefresh(o)) {
        refreshes++;
        return const FakeReply(500);
      }
      // So'rov eski token bilan ketgan payt boshqa so'rov tokenni yangiladi
      // (kesh sinxron yangilanadi).
      if (bearer(o) == 'A1') {
        unawaited(storage.updateTokens(accessToken: 'A2', refreshToken: 'R2'));
      }
      return api(o);
    });

    final res = await dio.get<Map<String, dynamic>>('/users/me');

    expect(res.statusCode, 200);
    expect(refreshes, 0);
  });

  test(
    'refresh tarmoq xatosi — qayta urinadi, tokenlar o`chirilmaydi',
    () async {
      var refreshes = 0;
      final dio = dioWith((o) {
        if (!isRefresh(o)) return api(o);
        refreshes++;
        return const FakeReply.offline();
      });

      final error = await dio
          .get<Map<String, dynamic>>('/users/me')
          .then<DioException?>(
            (_) => null,
            onError: (Object e) => e as DioException,
          );

      expect(error, isNotNull);
      expect(error!.response?.statusCode, 401);
      expect(error.requestOptions.extra[kAuthUnavailableExtra], isTrue);
      expect(refreshes, 3, reason: 'birinchi urinish + 2 ta qayta urinish');
      expect(await storage.readRefreshToken(), 'R1');
      expect(backend.store['jwt_tokens_v2'], isNotNull);
      expect(expiredCalls, 0);
    },
  );

  test('refresh 503 dan keyin 200 — muvaffaqiyat', () async {
    validAccess = {'A2'};
    var refreshes = 0;
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      refreshes++;
      return refreshes == 1
          ? const FakeReply(503, {'message': 'Service Unavailable'})
          : const FakeReply(200, {'accessToken': 'A2', 'refreshToken': 'R2'});
    });

    final res = await dio.get<Map<String, dynamic>>('/users/me');

    expect(res.statusCode, 200);
    expect(refreshes, 2);
    expect(expiredCalls, 0);
  });

  test('refresh 403 (proksi) — sessiya o`chirilmaydi', () async {
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      return const FakeReply(403, '<html>Forbidden</html>');
    });

    final error = await dio
        .get<Map<String, dynamic>>('/users/me')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );

    expect(error!.requestOptions.extra[kAuthUnavailableExtra], isTrue);
    expect(await storage.readRefreshToken(), 'R1');
    expect(expiredCalls, 0);
  });

  test('SESSION_REVOKED — tokenlar o`chiriladi va login chaqiriladi', () async {
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      return const FakeReply(401, {
        'code': 'SESSION_REVOKED',
        'reason': 'LOGOUT',
        'message': 'Session revoked',
      });
    });

    final error = await dio
        .get<Map<String, dynamic>>('/users/me')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );

    expect(error!.response?.statusCode, 401);
    expect(error.requestOptions.extra[kAuthUnavailableExtra], isNull);
    expect(error.requestOptions.extra[kAuthRevokedExtra], isTrue);
    expect(expiredCalls, 1);
    expect(await storage.readRefreshToken(), isNull);
    expect(backend.store, isEmpty);
  });

  test('"Session rotated" + xotirada yangiroq juftlik — tiklanadi', () async {
    validAccess = {'A3'};
    final seen = <String?>[];
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      seen.add(refreshArg(o));
      if (refreshArg(o) == 'R1') {
        // Boshqa yangilash shu payt yangi juftni yozib bo'lgan.
        backend.store['jwt_tokens_v2'] = jsonEncode({'a': 'A2', 'r': 'R2'});
        return const FakeReply(401, {'message': 'Session rotated'});
      }
      return const FakeReply(200, {'accessToken': 'A3', 'refreshToken': 'R3'});
    });

    final res = await dio.get<Map<String, dynamic>>('/users/me');

    expect(res.statusCode, 200);
    expect(seen, ['R1', 'R2']);
    expect(await storage.readRefreshToken(), 'R3');
    expect(expiredCalls, 0);
  });

  test('"Session rotated", yangiroq token yo`q — sessiya tugaydi', () async {
    var refreshes = 0;
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      refreshes++;
      return const FakeReply(401, {'message': 'Session rotated'});
    });

    final error = await dio
        .get<Map<String, dynamic>>('/users/me')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );

    expect(error!.response?.statusCode, 401);
    expect(refreshes, 1);
    expect(expiredCalls, 1);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('refresh token o`qilmasa — chiqarilmaydi (xotira xatosi)', () async {
    await storage.clear();
    TokenStorage.resetCacheForTest();
    backend.failReads = true;
    var refreshes = 0;
    final dio = dioWith((o) {
      if (isRefresh(o)) refreshes++;
      return api(o);
    });

    final error = await dio
        .get<Map<String, dynamic>>('/users/me')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );

    expect(error!.requestOptions.extra[kAuthUnavailableExtra], isTrue);
    expect(refreshes, 0);
    expect(expiredCalls, 0);
  });

  test('retry ham 401 bersa — ikkinchi refresh yo`q (sikl yo`q)', () async {
    var refreshes = 0;
    final dio = dioWith((o) {
      if (!isRefresh(o)) return const FakeReply(401);
      refreshes++;
      return const FakeReply(200, {'accessToken': 'A2', 'refreshToken': 'R2'});
    });

    final error = await dio
        .get<Map<String, dynamic>>('/users/me')
        .then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException,
        );

    expect(error!.response?.statusCode, 401);
    expect(refreshes, 1);
  });

  test('refresh paytida qayta kirilgan — eski javob yangi sessiyani '
      'o`chirmaydi', () async {
    RefreshTuning.retryDelays = const [
      Duration(milliseconds: 60),
      Duration(milliseconds: 60),
    ];
    validAccess = {'A9'};
    var refreshes = 0;
    final dio = dioWith((o) {
      if (!isRefresh(o)) return api(o);
      refreshes++;
      if (refreshes == 1) return const FakeReply.offline();
      return const FakeReply(401, {
        'code': 'SESSION_REVOKED',
        'reason': 'LOGOUT',
        'message': 'Session revoked',
      });
    });

    final request = dio.get<Map<String, dynamic>>('/users/me');
    // Refresh qayta urinishni kutayotganda foydalanuvchi chiqib, qayta kirdi.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await storage.saveTokens(accessToken: 'A9', refreshToken: 'R9');

    final res = await request;
    expect(res.statusCode, 200);
    expect(refreshes, 2);
    expect(await storage.readRefreshToken(), 'R9');
    expect(expiredCalls, 0);
  });

  test(
    'tokenlarni o`chirish xato bersa ham sessiya tugashi xabar qilinadi',
    () async {
      backend.failDeletes = true;
      final dio = dioWith((o) {
        if (!isRefresh(o)) return api(o);
        return const FakeReply(401, {'message': 'Token revoked'});
      });

      final error = await failureOf(dio.get<Map<String, dynamic>>('/users/me'));

      expect(error!.requestOptions.extra[kAuthRevokedExtra], isTrue);
      expect(expiredCalls, 1);
      expect(await storage.readRefreshToken(), isNull);
    },
  );

  test('takroriy so`rov 403 (tarif) — oyna bir marta chaqiriladi', () async {
    var lockedCalls = 0;
    onFeatureLocked = (_, _, _) => lockedCalls++;
    final dio = dioWith((o) {
      if (isRefresh(o)) {
        return const FakeReply(200, {
          'accessToken': 'A2',
          'refreshToken': 'R2',
        });
      }
      if (bearer(o) == 'A2') {
        return const FakeReply(403, {
          'code': 'FEATURE_NOT_IN_PLAN',
          'feature': 'growth',
          'message': 'Tarifda yo`q',
        });
      }
      return const FakeReply(401, {'message': 'Unauthorized'});
    });

    final error = await failureOf(dio.get<Map<String, dynamic>>('/growth'));

    expect(error!.response?.statusCode, 403);
    expect(lockedCalls, 1);
  });
}
