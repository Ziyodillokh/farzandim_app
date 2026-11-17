// AppRestriction.forPlatform — iPhone bola uchun faqat virtual "tanlangan
// ilovalar" cheklovi hisoblanadi (eski Android juftlik qoldiqlari emas).

import 'package:farzandim/core/utils/app_brand.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:flutter_test/flutter_test.dart';

AppRestriction _r(String pkg, {bool blocked = false, int minutes = 0}) =>
    AppRestriction(
      packageName: pkg,
      appName: pkg,
      limitMinutes: minutes,
      updatedAt: DateTime(2026, 10, 12),
      isBlocked: blocked,
    );

void main() {
  final all = [
    _r('com.whatsapp', blocked: true),
    _r(kIosSelectionPackage, minutes: 30),
    _r('com.android.chrome', minutes: 60),
  ];

  test('iPhone: faqat virtual yozuv cheklovi qoladi', () {
    final out = all.forPlatform(isIos: true);
    expect(out.map((r) => r.packageName), [kIosSelectionPackage]);
    expect(out.where((r) => r.isBlocked), isEmpty);
    expect(out.single.limitMinutes, 30);
  });

  test('iPhone: virtual cheklov yo`q → bo`sh (sanoq 0)', () {
    expect(
      [_r('com.whatsapp', blocked: true)].forPlatform(isIos: true),
      isEmpty,
    );
  });

  test('Android: ro`yxat o`zgarmaydi', () {
    expect(all.forPlatform(isIos: false), all);
  });
}
