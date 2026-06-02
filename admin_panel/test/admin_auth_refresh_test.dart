import 'dart:convert';

import 'package:admin_panel_flutter/core/network/admin_auth_refresh.dart';
import 'package:admin_panel_flutter/core/network/admin_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_token_storage.dart';
import 'support/stub_http_client_adapter.dart';
import 'support/test_jwt.dart';

void main() {
  setUp(() async {
    AdminSession.bindStorage(
      MemoryTokenStorage(
        accessToken: testAccessJwt(),
        refreshToken: 'r1',
      ),
    );
    await AdminSession.hydrate();
  });

  tearDown(() async {
    await AdminSession.clear();
  });

  test('refresh success updates session', () async {
    final next = testAccessJwt(expSecondsSinceEpoch: 4200000000);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = StubHttpClientAdapter((req) async {
      expect(req.path, '/auth/refresh');
      return ResponseBody.fromString(
        jsonEncode({'access_token': next, 'refresh_token': 'r2'}),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    });

    final got = await performTokenRefresh(dio);
    expect(got, next);
    expect(AdminSession.token, next);
    expect(AdminSession.refreshToken, 'r2');
  });

  test('refresh failure clears session', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = StubHttpClientAdapter((_) async {
      return ResponseBody.fromString('{}', 200, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
    });

    expect(await performTokenRefresh(dio), isNull);
    expect(AdminSession.token, isNull);
    expect(AdminSession.refreshToken, isNull);
    expect(AdminSession.isAuthenticated, isFalse);
  });
}
