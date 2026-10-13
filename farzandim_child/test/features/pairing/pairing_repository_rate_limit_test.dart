import 'package:dio/dio.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/features/pairing/data/repositories/pairing_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/network/fake_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PairingRepository repoReturning(int status) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = FakeHttpAdapter((_) => (status, null));
    return PairingRepository(dio: dio, tokenStorage: TokenStorage());
  }

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('429 is reported as rate limited, not as a network error', () async {
    final result = await repoReturning(429).verifyCode('12345', 'uid');

    expect(result, isA<PairingFailureRateLimited>());
  });

  test('404 is still an invalid code', () async {
    final result = await repoReturning(404).verifyCode('12345', 'uid');

    expect(result, isA<PairingFailureInvalidCode>());
  });

  test('5xx stays a network failure', () async {
    final result = await repoReturning(502).verifyCode('12345', 'uid');

    expect(result, isA<PairingFailureNetwork>());
  });
}
