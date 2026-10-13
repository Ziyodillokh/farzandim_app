import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthNameFrom', () {
    const months = 'yan,fev,mar,apr,may,iyn,iyl,avg,sen,okt,noy,dek';

    test('to\'g\'ri oy nomini qaytaradi', () {
      expect(monthNameFrom(months, 1), 'yan');
      expect(monthNameFrom(months, 10), 'okt');
      expect(monthNameFrom(months, 12), 'dek');
    });

    test('bo\'shliqlarni olib tashlaydi', () {
      expect(
        monthNameFrom('Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, '
            'Nov, Dec', 2),
        'Feb',
      );
    });

    test('noto\'g\'ri ro\'yxat yoki oy — oy raqami', () {
      expect(monthNameFrom('a,b,c', 2), '2');
      expect(monthNameFrom(months, 0), '0');
      expect(monthNameFrom(months, 13), '13');
    });
  });
}
