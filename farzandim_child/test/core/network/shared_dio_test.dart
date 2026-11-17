import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_memory.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/network/shared_dio_io.dart';
import 'package:farzandim_child/core/network/token_refresher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/secure_storage_fake.dart';
import 'scripted_adapter.dart';

class _CountingPool implements HttpClientAdapter {
  int fetches = 0;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetches++;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) => closed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageFake disk;

  setUp(() {
    disk = SecureStorageFake.install();
    SharedPreferences.setMockInitialValues({});
    TokenMemory.isolate.reset();
    resetSharedBackendDios();
    TokenRefresher.rotatedRetryDelay = Duration.zero;
    TokenRefresher.networkRetryDelays = const [Duration.zero, Duration.zero];
  });

  group('umumiy Dio', () {
    test('one Dio per isolate and account', () {
      final owner = createBackendDio(TokenStorage());
      final again = createBackendDio(TokenStorage());
      final guest = createBackendDio(TokenStorage(keyPrefix: 'acct_g_'));

      expect(identical(owner, again), isTrue);
      expect(identical(owner, guest), isFalse);
    });

    test('close() by one caller does not break the others', () async {
      final dio = createBackendDio(TokenStorage())
        ..httpClientAdapter = ScriptedAdapter((_) => const FakeReply(200));

      dio.close();
      final response = await createBackendDio(
        TokenStorage(),
      ).get<dynamic>('/children/me');

      expect(response.statusCode, 200);
    });

    test('idle connections stay open at least 30 s', () {
      expect(
        kIdleConnectionTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
      );
      expect(
        createBackendDio(TokenStorage()).httpClientAdapter,
        isA<FreshPoolAdapter>(),
      );
    });

    test('a pool idle longer than the timeout (wall clock) is replaced', () async {
      var now = DateTime(2026, 11, 14, 12);
      final pools = <_CountingPool>[];
      final adapter = FreshPoolAdapter(
        newPool: () {
          final pool = _CountingPool();
          pools.add(pool);
          return pool;
        },
        clock: () => now,
      );
      final options = RequestOptions(path: '/x');

      await adapter.fetch(options, null, null);
      now = now.add(const Duration(seconds: 20));
      await adapter.fetch(options, null, null); // bir tick — o'sha ulanish
      expect(pools, hasLength(1));
      expect(pools.single.fetches, 2);

      // Telefon uxladi: Dart taymeri yurmagan, lekin real vaqt o'tdi.
      now = now.add(const Duration(minutes: 5));
      await adapter.fetch(options, null, null);

      expect(pools, hasLength(2));
      expect(pools.first.closed, isTrue);
      expect(pools.last.fetches, 1);
    });

    test('guest requests carry the guest token', () async {
      await TokenStorage().saveTokens(accessToken: 'owner', refreshToken: 'r');
      await TokenStorage(
        keyPrefix: 'acct_g_',
      ).saveTokens(accessToken: 'guest', refreshToken: 'gr');
      final adapter = ScriptedAdapter((_) => const FakeReply(200));
      final dio = createBackendDio(TokenStorage(keyPrefix: 'acct_g_'))
        ..httpClientAdapter = adapter;

      await dio.get<dynamic>('/children/me');

      expect(bearerOf(adapter.requests.single), 'guest');
    });
  });

  group('interceptor xavfsizligi', () {
    test('a throwing token read does not hang the request', () async {
      disk.failReads = true;
      final adapter = ScriptedAdapter((_) => const FakeReply(200));
      final dio = createBackendDio(TokenStorage())..httpClientAdapter = adapter;

      final response = await dio
          .get<dynamic>('/children/me')
          .timeout(const Duration(seconds: 5));

      expect(response.statusCode, 200);
      expect(bearerOf(adapter.requests.single), isNull);
    });

    test('a throwing token read during 401 recovery does not hang', () async {
      disk.failReads = true;
      final dio = createBackendDio(TokenStorage())
        ..httpClientAdapter = ScriptedAdapter((_) => const FakeReply(401));

      await expectLater(
        dio.get<dynamic>('/children/me').timeout(const Duration(seconds: 5)),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
    });

    test('malformed Date header is ignored', () async {
      final dio = createBackendDio(TokenStorage())
        ..httpClientAdapter = ScriptedAdapter(
          (_) => const FakeReply(200, null, {'date': 'ertaga'}),
        );

      final response = await dio.get<dynamic>('/children/me');

      expect(response.statusCode, 200);
    });

    test('FormData uploads are re-sent after a refresh', () async {
      await TokenStorage().saveTokens(accessToken: 'old', refreshToken: 'r1');
      final adapter = ScriptedAdapter(
        (o) => switch (o.path) {
          '/auth/refresh' => const FakeReply(200, {
            'accessToken': 'new',
            'refreshToken': 'r2',
          }),
          _ when bearerOf(o) == 'new' => const FakeReply(200, {'ok': 1}),
          _ => const FakeReply(401),
        },
      );
      final dio = createBackendDio(TokenStorage())..httpClientAdapter = adapter;

      final response = await dio.post<dynamic>(
        '/voice-messages',
        data: FormData.fromMap({'text': 'salom'}),
      );

      expect(response.statusCode, 200);
      expect(adapter.paths, [
        '/voice-messages',
        '/auth/refresh',
        '/voice-messages',
      ]);
    });
  });
}
