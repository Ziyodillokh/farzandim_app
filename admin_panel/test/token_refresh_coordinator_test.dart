import 'package:admin_panel_flutter/core/network/token_refresh_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parallel callers await the same in-flight refresh', () async {
    var invocations = 0;
    Future<String?> slow() async {
      invocations++;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      return 'tok';
    }

    final a = TokenRefreshCoordinator.runLocked(slow);
    final b = TokenRefreshCoordinator.runLocked(slow);
    expect(identical(a, b), isTrue);
    expect(await a, 'tok');
    expect(await b, 'tok');
    expect(invocations, 1);
  });

  test('after completion a new refresh may run', () async {
    var n = 0;
    await TokenRefreshCoordinator.runLocked(() async {
      n++;
      return 'a';
    });
    await TokenRefreshCoordinator.runLocked(() async {
      n++;
      return 'b';
    });
    expect(n, 2);
  });
}
