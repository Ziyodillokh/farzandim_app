import 'package:farzandim_child/features/ranking/data/ranking_name_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('maskRankingName', () {
    test('ism + familiya bosh harfi', () {
      expect(maskRankingName('Akmal Toshmatov'), 'Akmal T.');
      expect(maskRankingName('  Muhammad   abror  '), 'Muhammad A.');
    });

    test('backend allaqachon niqoblagan ism o\'zgarmaydi', () {
      expect(maskRankingName('Akmal T.'), 'Akmal T.');
    });

    test('faqat bitta so\'z — familiya bosh harfisiz', () {
      expect(maskRankingName('Soliha'), 'Soliha');
    });

    test('3+ so\'z — faqat birinchi ism va ikkinchi so\'z bosh harfi', () {
      expect(maskRankingName('Ali Vali Valiyev'), 'Ali V.');
    });

    test("o'zbekcha apostroflar saqlanadi", () {
      expect(maskRankingName("G'ayrat O'rinov"), "G'ayrat O.");
      expect(maskRankingName('Oʻgʻiloy'), 'Oʻgʻiloy');
    });

    test('kirill harflari', () {
      expect(maskRankingName('Иван Петров'), 'Иван П.');
    });

    test('telefon raqami / bo\'sh / belgi — null', () {
      expect(maskRankingName('+998 90 123 45 67'), isNull);
      expect(maskRankingName(''), isNull);
      expect(maskRankingName('   '), isNull);
      expect(maskRankingName('—'), isNull);
    });

    test('@handle va raqamlar olib tashlanadi', () {
      expect(maskRankingName('@akmal_2012'), 'akmal');
      expect(maskRankingName('Akmal 99 Toshmatov'), 'Akmal T.');
    });

    test('juda uzun ism qisqartiriladi', () {
      final long = 'A' * 40;
      final masked = maskRankingName(long)!;
      expect(masked.length, kMaxMaskedFirstNameLength);
    });
  });

  group('rankingInitials', () {
    test('ikki harf', () {
      expect(rankingInitials('Akmal T.'), 'AT');
      expect(rankingInitials('akmal toshmatov'), 'AT');
    });

    test('bitta harf', () {
      expect(rankingInitials('Soliha'), 'S');
    });

    test('harf yo\'q — so\'roq belgisi', () {
      expect(rankingInitials(''), '?');
      expect(rankingInitials('123'), '?');
    });

    test('apostrof bilan boshlangan qism', () {
      expect(rankingInitials("G'ayrat O'rinov"), 'GO');
    });
  });
}
