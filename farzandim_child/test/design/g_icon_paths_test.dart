// Ikon path parseri: kanvasdagi glyflar Flutter'da to'g'ri chiziladi.

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M dan keyingi juftliklar chiziq sifatida o\'qiladi', () {
    final path = GIconPaths.parse('M10 10 20 10 20 20Z');

    final bounds = path.getBounds();

    expect(bounds, const Rect.fromLTRB(10, 10, 20, 20));
    expect(path.contains(const Offset(18, 12)), isTrue);
  });

  test('H, V va Q buyruqlari qo\'llab-quvvatlanadi', () {
    final path = GIconPaths.parse('M0 0H100V100Q50 150 0 100Z');

    final bounds = path.getBounds();

    expect(bounds.left, 0);
    expect(bounds.right, 100);
    expect(bounds.bottom, greaterThan(100));
  });

  test('bir xil satr qayta parse qilinmaydi (kesh)', () {
    const data = 'M1 1L5 1L5 5Z';

    expect(identical(GIconPaths.parse(data), GIconPaths.parse(data)), isTrue);
  });

  test('noma\'lum buyruq aniq xato beradi', () {
    expect(() => GIconPaths.parse('M0 0C1 1 2 2 3 3'), throwsFormatException);
  });

  test('barcha generatsiya qilingan glyflar 256 to\'r ichida', () {
    final icons = [
      GIcons.house,
      GIcons.bookOpen,
      GIcons.backpack,
      GIcons.user,
      GIcons.caretLeft,
      GIcons.heart,
    ];
    for (final icon in icons) {
      for (final data in [icon.primary, icon.secondary]) {
        final bounds = GIconPaths.parse(data).getBounds();
        expect(bounds.left, greaterThanOrEqualTo(-1), reason: data);
        expect(bounds.top, greaterThanOrEqualTo(-1));
        expect(bounds.right, lessThanOrEqualTo(257));
        expect(bounds.bottom, lessThanOrEqualTo(257));
        expect(bounds.width, greaterThan(0));
      }
    }
  });
}
