// Sessiya faqat server ANIQ bekor qilganda yopiladi (SESSION_REVOKED,
// 'Token revoked', 'User not found or inactive'). Boshqa har qanday 401,
// tarmoq xatosi yoki o'qilmagan token — tokenlarga tegilmaydi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_memory.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/network/token_refresher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late List<SessionRevoked> events;
  late StreamSubscription<SessionRevoked> sub;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    TokenMemory.isolate.reset();
    resetSharedBackendDios();
    TokenStorage.missingRecheckDelay = Duration.zero;
    TokenRefresher.rotatedRetryDelay = Duration.zero;
    TokenRefresher.networkRetryDelays = const [Duration.zero, Duration.zero];
    storage = TokenStorage();
    events = [];
    sub = SessionEvents.revoked.listen(events.add);
  });

  tearDown(() => sub.cancel());

  Dio dioWith(FakeHttpAdapter adapter) =>
      createBackendDio(storage)..httpClientAdapter = adapter;

  Future<void> expect401(Dio dio) => expectLater(
    dio.get<dynamic>('/children/me'),
    throwsA(isA<DioException>()),
  );

  test('SESSION_REVOKED clears tokens and reports the reason', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final adapter = FakeHttpAdapter(
      (o) => o.path == '/auth/refresh'
          ? (
              401,
              {
                'code': 'SESSION_REVOKED',
                'reason': 'SIGNED_OUT',
                'message': 'Session revoked',
              },
            )
          : (401, null),
    );

    await expect401(dioWith(adapter));
    await Future<void>.delayed(Duration.zero);

    expect(adapter.requestedPaths, ['/children/me', '/auth/refresh']);
    expect(await storage.hasValidSession(), isFalse);
    expect(await storage.isSessionDefinitelyMissing(), isTrue);
    expect(events.single.reason, 'SIGNED_OUT');
    expect(events.single.isOwner, isTrue);
  });

  for (final message in ['Token revoked', 'User not found or inactive']) {
    test('"$message" clears tokens and reports revocation', () async {
      await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
      final adapter = FakeHttpAdapter(
        (o) => o.path == '/auth/refresh'
            ? (401, {'statusCode': 401, 'message': message})
            : (401, null),
      );

      await expect401(dioWith(adapter));
      await Future<void>.delayed(Duration.zero);

      expect(await storage.hasValidSession(), isFalse);
      expect(events, hasLength(1));
      expect(events.single.reason, isNull);
    });
  }

  for (final body in <Object?>[
    {'statusCode': 401, 'message': 'Session rotated'},
    {'statusCode': 401, 'message': 'Invalid refresh token'},
    {'message': 'revoked'},
    null,
  ]) {
    test('refresh 401 $body never clears the session', () async {
      await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
      final adapter = FakeHttpAdapter(
        (o) => o.path == '/auth/refresh' ? (401, body) : (401, null),
      );

      await expect401(dioWith(adapter));
      await Future<void>.delayed(Duration.zero);

      expect(await storage.readRefreshToken(), 'r1');
      expect(await storage.isSessionDefinitelyMissing(), isFalse);
      expect(events, isEmpty);
    });
  }

  test('401 with no tokens anywhere is unknown, not a revocation', () async {
    final adapter = FakeHttpAdapter((_) => (401, null));

    await expect401(dioWith(adapter));
    await Future<void>.delayed(Duration.zero);

    expect(adapter.requestedPaths, ['/children/me']);
    expect(events, isEmpty);
  });

  test('temporary refresh failure keeps the session', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final adapter = FakeHttpAdapter(
      (o) => o.path == '/auth/refresh' ? (503, null) : (401, null),
    );

    await expect401(dioWith(adapter));
    await Future<void>.delayed(Duration.zero);

    // 60 s imtiyoz ichida yana 2 marta urinildi.
    expect(adapter.requestedPaths.where((p) => p == '/auth/refresh'), hasLength(3));
    expect(await storage.hasValidSession(), isTrue);
    expect(events, isEmpty);
  });

  test('successful refresh saves the new pair and retries once', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final adapter = FakeHttpAdapter(
      (o) => switch (o.path) {
        '/auth/refresh' => (200, {'accessToken': 'new', 'refreshToken': 'r2'}),
        _ when o.headers['Authorization'] == 'Bearer new' => (200, {'ok': 1}),
        _ => (401, null),
      },
    );

    final response = await dioWith(adapter).get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(adapter.requestedPaths, [
      '/children/me',
      '/auth/refresh',
      '/children/me',
    ]);
    expect(await storage.readAccessToken(), 'new');
    expect(await storage.readRefreshToken(), 'r2');
  });

  test('event carries the account scope and the server reason', () async {
    await storage.saveTokens(accessToken: 'owner', refreshToken: 'owner-r');
    final guest = TokenStorage(keyPrefix: 'acct_c9_');
    await guest.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final adapter = FakeHttpAdapter(
      (o) => o.path == '/auth/refresh'
          ? (401, {'code': 'SESSION_REVOKED', 'reason': 'RECOVERED'})
          : (401, null),
    );

    await expectLater(
      (createBackendDio(guest)..httpClientAdapter = adapter).get<dynamic>(
        '/children/me',
      ),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events.single.scope, 'acct_c9_');
    expect(events.single.isOwner, isFalse);
    expect(events.single.reason, 'RECOVERED');
    // Qurilma egasining tokenlariga tegilmaydi.
    expect(await storage.readRefreshToken(), 'owner-r');
    expect(await guest.readRefreshToken(), isNull);
  });

  test('a session saved meanwhile survives the old one\'s revocation', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r-old');
    final adapter = FakeHttpAdapter((o) {
      if (o.path == '/auth/refresh') {
        // Shu orada qayta kirish (boshqa isolate) yangi sessiyani yozdi.
        unawaited(
          TokenStorage(
            memory: TokenMemory(),
          ).saveTokens(accessToken: 'new', refreshToken: 'r-new'),
        );
        return (401, {'code': 'SESSION_REVOKED', 'reason': 'SIGNED_OUT'});
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? (200, {'ok': 1})
          : (401, null);
    });

    final response = await dioWith(adapter).get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(events, isEmpty);
    expect(await storage.readRefreshToken(), 'r-new');
  });
}
