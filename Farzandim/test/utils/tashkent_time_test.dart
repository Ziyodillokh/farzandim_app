// tashkent_time (ARCH-08) — UTC+5 hisoblari.

import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tashkentNow', () {
    test('UTC dan roppa-rosa 5 soat oldinda', () {
      final utc = DateTime.now().toUtc();
      final tk = tashkentNow();
      final diff = tk.difference(utc).inMinutes;
      // 299-301 daqiqa oralig'i (chaqiruvlar orasidagi millisekundlar uchun).
      expect(diff, inInclusiveRange(299, 301));
    });
  });

  group('tashkentTodayStr', () {
    test('YYYY-MM-DD formatda (backend kun-kaliti)', () {
      final s = tashkentTodayStr();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s), isTrue);
      final t = tashkentNow();
      expect(s, startsWith(t.year.toString()));
    });
  });
}
