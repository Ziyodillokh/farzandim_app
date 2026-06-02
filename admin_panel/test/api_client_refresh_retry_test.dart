import 'dart:convert';
import 'dart:typed_data';

import 'package:admin_panel_flutter/core/network/admin_session.dart';
import 'package:admin_panel_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_token_storage.dart';
import 'support/test_jwt.dart';

final _json = {Headers.contentTypeHeader: ['application/json']};

final class _RetryScenarioAdapter implements HttpClientAdapter {
  _RetryScenarioAdapter(this._jwt2);

  final String _jwt2;
  int refreshCalls = 0;
  int protectedGets = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/auth/refresh')) {
      refreshCalls++;
      final body = jsonEncode({
        'access_token': _jwt2,
        'refresh_token': 'r1',
      });
      return ResponseBody.fromString(body, 200, headers: _json);
    }
    if (path.endsWith('/protected')) {
      protectedGets++;
      final auth = options.headers['Authorization'] as String?;
      if (protectedGets == 1) {
        return ResponseBody.fromString('{}', 401, headers: _json);
      }
      expect(auth, 'Bearer $_jwt2');
      return ResponseBody.fromString('{"ok":true}', 200, headers: _json);
    }
    fail('unexpected path $path');
  }
}

void main() {
  late String jwt1;
  late String jwt2;
  late _RetryScenarioAdapter adapter;

  setUp(() async {
    jwt1 = testAccessJwt();
    jwt2 = testAccessJwt(expSecondsSinceEpoch: 4200000000);
    adapter = _RetryScenarioAdapter(jwt2);
    AdminSession.bindStorage(
      MemoryTokenStorage(accessToken: jwt1, refreshToken: 'r1'),
    );
    await AdminSession.hydrate();
  });

  tearDown(() async {
    await AdminSession.clear();
  });

  test('401 triggers single refresh and one retry', () async {
    final main = Dio(BaseOptions(baseUrl: 'http://test'));
    main.httpClientAdapter = adapter;
    final refresh = Dio(BaseOptions(baseUrl: 'http://test'));
    refresh.httpClientAdapter = adapter;

    final client = ApiClient(client: main, refreshDio: refresh);
    final res = await client.get('/protected');
    expect(res.statusCode, 200);
    expect(adapter.refreshCalls, 1);
    expect(adapter.protectedGets, 2);
    expect(AdminSession.token, jwt2);
  });
}
