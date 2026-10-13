import 'package:farzandim_child/features/screen_time/domain/banner_snooze.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12);
  int msAgo(Duration d) => now.subtract(d).millisecondsSinceEpoch;

  test('never dismissed — banner is shown', () {
    expect(isBannerSnoozed(dismissedAtMs: null, now: now), isFalse);
  });

  test('dismissed recently — banner stays hidden', () {
    expect(
      isBannerSnoozed(dismissedAtMs: msAgo(const Duration(days: 2)), now: now),
      isTrue,
    );
  });

  test('banner comes back after the snooze period', () {
    expect(
      isBannerSnoozed(
        dismissedAtMs: msAgo(
          kLocationBannerSnooze + const Duration(minutes: 1),
        ),
        now: now,
      ),
      isFalse,
    );
  });

  test(
    'a dismissal time in the future (clock moved back) shows the banner',
    () {
      expect(
        isBannerSnoozed(
          dismissedAtMs: now
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
          now: now,
        ),
        isFalse,
      );
    },
  );
}
