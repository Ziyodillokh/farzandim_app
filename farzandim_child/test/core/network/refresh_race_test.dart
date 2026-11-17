// Ikki isolate (har biri o'z token xotirasi va o'z Dio'si bilan) bitta
// secure storage va bitta backend'ga qarshi bir vaqtda refresh qiladi.
// Avval bu holat sessiyani o'chirib, bolani juftlashdan chiqarardi
// (fn-refresh-race-logout, rob-dart-refresh-race-session-wipe).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_memory.dart';
import 'package:farzandim_child/core/auth/token_pair.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/network/token_refresher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/secure_storage_fake.dart';
import 'fake_auth_backend.dart';
import 'scripted_adapter.dart';

/// Bitta "isolate": o'z xotirasi, o'z refresh holati, umumiy disk/backend.
class _Isolate {
  _Isolate(FakeAuthBackend backend)
    : storage = TokenStorage(memory: TokenMemory()),
      adapter = ScriptedAdapter(backend.handle) {
    dio = buildBackendDio(storage)..httpClientAdapter = adapter;
  }

  final TokenStorage storage;
  final ScriptedAdapter adapter;
  late final Dio dio;

  int get refreshes => adapter.countOf('/auth/refresh');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageFake disk;
  late FakeAuthBackend backend;
  late List<SessionRevoked> events;
  late StreamSubscription<SessionRevoked> sub;

  setUp(() {
    disk = SecureStorageFake.install();
    SharedPreferences.setMockInitialValues({});
    TokenRefresher.rotatedRetryDelay = const Duration(milliseconds: 10);
    TokenRefresher.networkRetryDelays = const [Duration.zero, Duration.zero];
    backend = FakeAuthBackend();
    events = [];
    sub = SessionEvents.revoked.listen(events.add);
  });

  tearDown(() => sub.cancel());

  Future<TokenPair> seed() async {
    final pair = backend.initialPair();
    await TokenStorage(memory: TokenMemory()).saveTokens(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
    );
    return pair;
  }

  Future<TokenPair?> storedPair() async =>
      (await TokenStorage(memory: TokenMemory()).reload()).pair;

  test('two isolates refreshing at once keep the session', () async {
    await seed();
    backend.refreshLatency = const Duration(milliseconds: 20);
    final a = _Isolate(backend);
    final b = _Isolate(backend);

    final responses = await Future.wait([
      for (var i = 0; i < 3; i++) a.dio.get<dynamic>('/children/me'),
      for (var i = 0; i < 3; i++) b.dio.get<dynamic>('/children/me'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    // Isolate ichida bitta refresh (single-flight); ikkalasi bir vaqtda.
    expect(a.refreshes, 1);
    expect(b.refreshes, 1);
    expect(backend.refreshCalls, 2);
    expect(events, isEmpty);
    final stored = await storedPair();
    expect(backend.isCurrentRefresh(stored!.refreshToken), isTrue);
  });

  test('old backend (no grace): concurrent refresh never wipes', () async {
    final initial = await seed();
    backend
      ..grace = Duration.zero
      ..refreshLatency = const Duration(milliseconds: 30);
    final a = _Isolate(backend);
    final b = _Isolate(backend);

    final results = await Future.wait([
      a.dio.get<dynamic>('/children/me').then((r) => r.statusCode),
      b.dio
          .get<dynamic>('/children/me')
          .then((r) => r.statusCode, onError: (Object _) => 401),
    ]);

    expect(results.first, 200);
    expect(events, isEmpty);
    final stored = await storedPair();
    expect(stored, isNot(initial));
    expect(backend.isCurrentRefresh(stored!.refreshToken), isTrue);
    // B yutqazgan bo'lsa ham keyingi so'rovi diskdagi yangi token bilan o'tadi.
    final again = await b.dio.get<dynamic>('/children/me');
    expect(again.statusCode, 200);
    expect(events, isEmpty);
  });

  test('without the server grace, Session rotated recovers from storage', () async {
    final initial = await seed();
    backend.grace = Duration.zero;
    final b = _Isolate(backend);
    await b.storage.accessTokenForRequest(); // B xotirasida eski juft

    // A isolate'i refresh qildi; uning yozuvi B 'Session rotated' javobini
    // olgandan KEYIN diskka tushadi (eski klient shu zahoti qayta o'qib,
    // o'zgarmagan tokenni ko'rib, sessiyani o'chirardi).
    final rotated = backend.rotate();
    backend.beforeRotatedReply = () async {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 3),
          () => TokenStorage(memory: TokenMemory()).saveTokens(
            accessToken: rotated.accessToken,
            refreshToken: rotated.refreshToken,
          ),
        ),
      );
    };

    final response = await b.dio.get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(bearerOf(b.adapter.requests.last), rotated.accessToken);
    expect(b.refreshes, 1);
    expect(events, isEmpty);
    expect(await storedPair(), rotated);
    expect(initial, isNot(rotated));
  });

  test('a newer token in storage is used without refreshing', () async {
    await seed();
    final b = _Isolate(backend);
    await b.storage.accessTokenForRequest();
    final rotated = backend.rotate();
    await TokenStorage(memory: TokenMemory()).saveTokens(
      accessToken: rotated.accessToken,
      refreshToken: rotated.refreshToken,
    );

    final response = await b.dio.get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(b.refreshes, 0);
    expect(b.storage.cachedPair, rotated);
  });

  test('an expired token from the other isolate still leads to a refresh', () async {
    await seed();
    final b = _Isolate(backend);
    await b.storage.accessTokenForRequest(); // B xotirasida eski juft
    // A refresh qilib diskka yozgan, lekin uning access tokeni ham eskirgan.
    final rotated = backend.rotate();
    backend.validAccess.remove(rotated.accessToken);
    await TokenStorage(memory: TokenMemory()).saveTokens(
      accessToken: rotated.accessToken,
      refreshToken: rotated.refreshToken,
    );

    final response = await b.dio.get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(b.refreshes, 1);
    expect(events, isEmpty);
    expect(backend.isCurrentRefresh(b.storage.cachedPair!.refreshToken), isTrue);
  });

  test('Session rotated with nothing newer never clears the tokens', () async {
    final initial = await seed();
    backend.grace = Duration.zero;
    backend.rotate(); // boshqa jarayon rotatsiya qildi, javob bizga yetmadi
    final b = _Isolate(backend);

    await expectLater(
      b.dio.get<dynamic>('/children/me'),
      throwsA(
        isA<DioException>().having((e) => e.response?.statusCode, 'status', 401),
      ),
    );

    expect(events, isEmpty);
    expect(await storedPair(), initial);
    expect(b.storage.cachedPair, initial);
    expect(await b.storage.isSessionDefinitelyMissing(), isFalse);
  });

  test('an older pair on disk never replaces a newer one in memory', () async {
    final initial = await seed();
    final a = _Isolate(backend);
    await a.dio.get<dynamic>('/children/me'); // A refresh qildi
    final fresh = a.storage.cachedPair!;
    expect(fresh, isNot(initial));

    // Boshqa isolate eski juftni qayta yozdi (masalan kechikkan ko'chirish).
    await TokenStorage(memory: TokenMemory()).saveTokens(
      accessToken: initial.accessToken,
      refreshToken: initial.refreshToken,
    );
    await a.storage.reload();

    expect(a.storage.cachedPair, fresh);
    final response = await a.dio.get<dynamic>('/children/me');
    expect(response.statusCode, 200);
    expect(bearerOf(a.adapter.requests.last), fresh.accessToken);
  });

  test('sticky-null secure storage does not wipe the session', () async {
    await seed();
    final b = _Isolate(backend);
    await b.storage.accessTokenForRequest();
    disk.stickyNull = true; // Keystore xatosi: endi har o'qish null

    final response = await b.dio.get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(b.refreshes, 1);
    expect(events, isEmpty);
    expect(await b.storage.isSessionDefinitelyMissing(), isFalse);
    disk.stickyNull = false;
    expect(backend.isCurrentRefresh((await storedPair())!.refreshToken), isTrue);
  });

  test('parallel 401s in one isolate share a single refresh', () async {
    await seed();
    final a = _Isolate(backend);

    await Future.wait([
      for (var i = 0; i < 5; i++) a.dio.get<dynamic>('/children/me'),
    ]);

    expect(a.refreshes, 1);
    expect(backend.refreshCalls, 1);
  });

  test('a 401 with a just-issued token does not refresh again', () async {
    await seed();
    final a = _Isolate(backend);
    await a.dio.get<dynamic>('/children/me');
    expect(a.refreshes, 1);

    for (var i = 0; i < 3; i++) {
      await expectLater(
        a.dio.get<dynamic>('/always-401'),
        throwsA(isA<DioException>()),
      );
    }

    expect(a.refreshes, 1);
  });

  test('network errors during refresh are retried and never clear', () async {
    final initial = await seed();
    final a = _Isolate(backend);
    var failures = 0;
    final flaky = ScriptedAdapter((o) {
      if (o.path == '/auth/refresh' && failures < 2) {
        failures++;
        return const FakeReply.networkError();
      }
      return backend.handle(o);
    });
    a.dio.httpClientAdapter = flaky;

    final response = await a.dio.get<dynamic>('/children/me');

    expect(response.statusCode, 200);
    expect(flaky.countOf('/auth/refresh'), 3);
    expect(events, isEmpty);
    expect(await storedPair(), isNot(initial));
  });

  test('a refresh that never gets through keeps the session', () async {
    final initial = await seed();
    final a = _Isolate(backend);
    final offline = ScriptedAdapter(
      (o) => o.path == '/auth/refresh'
          ? const FakeReply.networkError()
          : backend.handle(o),
    );
    a.dio.httpClientAdapter = offline;

    await expectLater(
      a.dio.get<dynamic>('/children/me'),
      throwsA(isA<DioException>()),
    );

    expect(events, isEmpty);
    expect(await storedPair(), initial);
  });
}
