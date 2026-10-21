// Davriy yangilash siyraklashtiriladi; majburiy (ilovaga qaytish) — har doim.

import 'package:farzandim_child/core/utils/refresh_throttle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oraliq o\'tmaguncha davriy yangilash yo\'q', () {
    var now = DateTime(2026, 10, 21, 9);
    final throttle = RefreshThrottle(
      const Duration(minutes: 5),
      clock: () => now,
    );

    now = now.add(const Duration(minutes: 1));
    expect(throttle.shouldRun(), isFalse);
    now = now.add(const Duration(minutes: 3));
    expect(throttle.shouldRun(), isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(throttle.shouldRun(), isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(throttle.shouldRun(), isFalse);
  });

  test('majburiy yangilash har doim va hisobni qayta boshlaydi', () {
    var now = DateTime(2026, 10, 21, 9);
    final throttle = RefreshThrottle(
      const Duration(minutes: 5),
      clock: () => now,
    );

    now = now.add(const Duration(minutes: 1));
    expect(throttle.shouldRun(force: true), isTrue);
    now = now.add(const Duration(minutes: 4));
    expect(throttle.shouldRun(), isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(throttle.shouldRun(), isTrue);
  });
}
