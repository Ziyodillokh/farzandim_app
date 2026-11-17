// Ilova ochilishi (bootstrap): internet uzilishi yoki Keystore xatosi
// foydalanuvchini login'ga chiqarmaydi; faqat server sessiyani bekor qilsa.

import 'dart:convert';

import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/auth/data/repositories/backend_auth_repository.dart';
import 'package:farzandim/features/auth/data/services/social_sign_in_service.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
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
  final defaultRetryDelays = RefreshTuning.retryDelays;
  final defaultRotatedDelay = RefreshTuning.rotatedRecheckDelay;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth.cached_user.v1': jsonEncode({'id': 'u1', 'role': 'PARENT'}),
    });
    TokenStorage.resetCacheForTest();
    RefreshTuning.retryDelays = const [Duration.zero, Duration.zero];
    RefreshTuning.rotatedRecheckDelay = Duration.zero;
    backend = MemoryBackend();
    storage = TokenStorage(backend: backend);
    await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiBaseUrlProvider.overrideWithValue('https://api.test/api'),
      ],
    );
  });

  tearDown(() {
    onSessionExpired = null;
    RefreshTuning.retryDelays = defaultRetryDelays;
    RefreshTuning.rotatedRecheckDelay = defaultRotatedDelay;
    container.dispose();
  });

  Future<BackendAuthNotifier> boot(
    FakeReply Function(String path) server,
  ) async {
    final dio = container.read(dioClientProvider)
      ..httpClientAdapter = FakeHttpAdapter((o) => server(o.path));
    final notifier = BackendAuthNotifier(
      repository: BackendAuthRepository(dio: dio, tokenStorage: storage),
      socialSignIn: SocialSignInService(),
    );
    await notifier.bootstrapDone;
    return notifier;
  }

  test(
    'access eskirgan, refresh paytida internet yo`q — kirgan qoladi',
    () async {
      final notifier = await boot(
        (path) => path.contains('/auth/refresh')
            ? const FakeReply.offline()
            : const FakeReply(401, {'message': 'Unauthorized'}),
      );

      expect(notifier.state, isA<AuthAuthenticated>());
      expect(await storage.readRefreshToken(), 'R1');
      expect(backend.store['jwt_tokens_v2'], isNotNull);
    },
  );

  test('refresh 502 (server qayta ishga tushmoqda) — kirgan qoladi', () async {
    final notifier = await boot(
      (path) => path.contains('/auth/refresh')
          ? const FakeReply(502)
          : const FakeReply(401, {'message': 'Unauthorized'}),
    );

    expect(notifier.state, isA<AuthAuthenticated>());
    expect(await storage.readRefreshToken(), 'R1');
  });

  test('Keystore null qaytarsa (belgi bor) — login`ga chiqarilmaydi', () async {
    TokenStorage.resetCacheForTest();
    backend.nullReads = true;
    var refreshes = 0;

    final notifier = await boot((path) {
      if (path.contains('/auth/refresh')) refreshes++;
      return const FakeReply(401, {'message': 'Unauthorized'});
    });

    expect(notifier.state, isA<AuthAuthenticated>());
    expect(refreshes, 0, reason: 'token o`qilmadi — refresh yuborilmaydi');
    expect(backend.store['jwt_tokens_v2'], isNotNull);
  });

  test('eskirgan token poygasi (retry ham 401) — chiqarilmaydi', () async {
    final notifier = await boot((path) {
      if (path.contains('/auth/refresh')) {
        return const FakeReply(200, {
          'accessToken': 'A2',
          'refreshToken': 'R2',
        });
      }
      return const FakeReply(401, {'message': 'Unauthorized'});
    });

    expect(notifier.state, isA<AuthAuthenticated>());
    expect(await storage.readRefreshToken(), 'R2');
  });

  test('server sessiyani bekor qilgan (SESSION_REVOKED) — login', () async {
    final notifier = await boot(
      (path) => path.contains('/auth/refresh')
          ? const FakeReply(401, {
              'code': 'SESSION_REVOKED',
              'reason': 'SIGNED_IN_ELSEWHERE',
              'message': 'Session revoked',
            })
          : const FakeReply(401, {'message': 'Unauthorized'}),
    );

    expect(notifier.state, isA<AuthAnonymous>());
    expect(await storage.readRefreshToken(), isNull);
  });

  test('server tasdiqlasa — yangi profil bilan kirgan holat', () async {
    final notifier = await boot(
      (_) =>
          const FakeReply(200, {'id': 'u1', 'role': 'PARENT', 'name': 'Ota'}),
    );

    final state = notifier.state;
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.displayName, 'Ota');
  });
}
