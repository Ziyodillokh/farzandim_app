// SwrCache (NET-07) — disk SWR keshi: yozish/o'qish, buzuq format,
// XAVFSIZLIK (clearAll logout'da boshqa akkaunt ma'lumotini tozalaydi).

import 'package:farzandim/core/cache/swr_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SwrCache', () {
    test('yozilgan qiymat o`qiladi (savedAt bilan)', () async {
      await SwrCache.write('k1', [
        {'id': 'a'},
      ]);
      final got = await SwrCache.read('k1');
      expect(got, isNotNull);
      final (data, savedAt) = got!;
      expect(data, isA<List<dynamic>>());
      expect((data! as List).first, {'id': 'a'});
      expect(
        DateTime.now().difference(savedAt).inSeconds.abs() < 5,
        isTrue,
      );
    });

    test('yo`q kalit → null', () async {
      expect(await SwrCache.read('mavjud_emas'), isNull);
    });

    test('buzuq JSON → null (crash YO`Q)', () async {
      SharedPreferences.setMockInitialValues({
        'swr_cache_v1:buzuq': 'bu json emas{{{',
      });
      expect(await SwrCache.read('buzuq'), isNull);
    });

    test('evict bitta kalitni o`chiradi', () async {
      await SwrCache.write('k1', 'v1');
      await SwrCache.evict('k1');
      expect(await SwrCache.read('k1'), isNull);
    });

    test('clearAll FAQAT swr kalitlarni o`chiradi (XAVFSIZLIK)', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_history_v1': 'saqlanishi kerak',
      });
      await SwrCache.write('children', ['c1']);
      await SwrCache.write('weekly_usage:c1', [1, 2]);

      await SwrCache.clearAll();

      expect(await SwrCache.read('children'), isNull);
      expect(await SwrCache.read('weekly_usage:c1'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('notifications_history_v1'),
        'saqlanishi kerak',
      );
    });
  });
}
