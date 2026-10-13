import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late List<void> events;
  late StreamSubscription<void> sub;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage();
    events = [];
    sub = SessionEvents.revoked.listen(events.add);
  });

  tearDown(() => sub.cancel());

  Dio dioWith(FakeHttpAdapter adapter) =>
      createBackendDio(storage)..httpClientAdapter = adapter;

  test(
    'refresh rejected with 401 clears tokens and reports revocation',
    () async {
      await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
      final adapter = FakeHttpAdapter((_) => (401, {'message': 'revoked'}));

      await expectLater(
        dioWith(adapter).get<dynamic>('/children/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(adapter.requestedPaths, ['/children/me', '/auth/refresh']);
      expect(await storage.hasValidSession(), isFalse);
      expect(await storage.isSessionDefinitelyMissing(), isTrue);
      expect(events, hasLength(1));
    },
  );

  test('401 with no refresh token at all reports revocation', () async {
    final adapter = FakeHttpAdapter((_) => (401, null));

    await expectLater(
      dioWith(adapter).get<dynamic>('/children/me'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(adapter.requestedPaths, ['/children/me']);
    expect(events, hasLength(1));
  });

  test('temporary refresh failure keeps the session', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final adapter = FakeHttpAdapter(
      (o) => o.path == '/auth/refresh' ? (503, null) : (401, null),
    );

    await expectLater(
      dioWith(adapter).get<dynamic>('/children/me'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await storage.hasValidSession(), isTrue);
    expect(events, isEmpty);
  });
}
