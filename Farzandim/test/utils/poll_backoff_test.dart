// PollBackoff — ketma-ket xatolarda polling siyraklashishi (PERF).

import 'package:farzandim/core/utils/poll_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PollBackoff', () {
    test('toza holatda hech narsa tashlanmaydi', () {
      final b = PollBackoff();
      expect(b.shouldSkipTick, isFalse);
      expect(b.shouldSkipTick, isFalse);
    });

    test('har xato keyingi skiplarni oshiradi, muvaffaqiyat reset qiladi',
        () {
      final b = PollBackoff()

        // 1-xato → 1 tick skip
        ..onFailure();
      expect(b.shouldSkipTick, isTrue);
      expect(b.shouldSkipTick, isFalse);

      // 2-xato (streak 2) → 2 tick skip
      b.onFailure();
      expect(b.shouldSkipTick, isTrue);
      expect(b.shouldSkipTick, isTrue);
      expect(b.shouldSkipTick, isFalse);

      // muvaffaqiyat — streak reset, keyingi xato yana 1 tick
      b
        ..onSuccess()
        ..onFailure();
      expect(b.shouldSkipTick, isTrue);
      expect(b.shouldSkipTick, isFalse);
    });

    test('skip 4 tick bilan cheklanadi (60s poll -> max ~5 daqiqa)', () {
      final b = PollBackoff();
      for (var i = 0; i < 10; i++) {
        b.onFailure();
        while (b.shouldSkipTick) {}
      }
      b.onFailure();
      var skips = 0;
      while (b.shouldSkipTick) {
        skips++;
      }
      expect(skips, 4);
    });
  });
}
