// 6 default avatar fayli haqiqatan asset-bundle'ga tushganini tekshiradi
// (pubspec e'loni + fayl mavjudligi + getter yo'li mosligi).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const paths = [
    'assets/default_avatars/boy_6_10.png',
    'assets/default_avatars/boy_10_14.png',
    'assets/default_avatars/boy_14.png',
    'assets/default_avatars/girl_6_10.png',
    'assets/default_avatars/girl_10_14.png',
    'assets/default_avatars/girl_14.png',
  ];

  for (final p in paths) {
    test('bundle: $p yuklanadi va bo`sh emas', () async {
      final data = await rootBundle.load(p);
      expect(data.lengthInBytes, greaterThan(1000), reason: '$p bo`sh/yo`q');
    });
  }
}
