import 'package:flutter_test/flutter_test.dart';

import 'support/memory_token_storage.dart';

void main() {
  test('MemoryTokenStorage persists access and refresh', () async {
    final s = MemoryTokenStorage();
    await s.writeAccessToken('a');
    await s.writeRefreshToken('r');
    expect(await s.readAccessToken(), 'a');
    expect(await s.readRefreshToken(), 'r');

    await s.clearRefreshToken();
    expect(await s.readRefreshToken(), isNull);
    expect(await s.readAccessToken(), 'a');

    await s.clearAll();
    expect(await s.readAccessToken(), isNull);
  });
}
