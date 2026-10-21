// Maktab taklif kodi: backend `redeemSchema` bilan bir xil normallashtirish,
// "XXXX-XXXX" ko'rinishi va panel QR havolasidan kod olish.

import 'package:farzandim/features/school/data/invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalize', () {
    test('bo`shliq va chiziqcha olinadi, katta harf bo`ladi', () {
      expect(InviteCode.normalize('abcd-2345 '), 'ABCD2345');
      expect(InviteCode.normalize(' ab cd\t23-45\n'), 'ABCD2345');
    });

    test('boshqa belgilar o`zgarmaydi (tekshiruv ularni rad etadi)', () {
      expect(InviteCode.normalize('ab_cd'), 'AB_CD');
    });
  });

  group('isValid', () {
    test('8 ta lotin harf/raqam — to`g`ri', () {
      expect(InviteCode.isValid('ABCD2345'), isTrue);
      expect(InviteCode.isValid('abcd-2345 '), isTrue);
      expect(InviteCode.isValid('ZZZZZZ22'), isTrue);
    });

    test('qisqa, uzun, bo`sh yoki begona belgili — rad etiladi', () {
      expect(InviteCode.isValid(''), isFalse);
      expect(InviteCode.isValid('AB'), isFalse);
      expect(InviteCode.isValid('ABCD23456'), isFalse);
      expect(InviteCode.isValid('ABCD-23!5'), isFalse);
      expect(InviteCode.isValid('ABCD_234'), isFalse);
      // Kirill "А" lotin "A"ga o'xshaydi, lekin backend uni qabul qilmaydi.
      expect(InviteCode.isValid('АBCD2345'), isFalse);
    });
  });

  group('format', () {
    test('to`liq kod "XXXX-XXXX" bo`ladi', () {
      expect(InviteCode.format('abcd2345'), 'ABCD-2345');
      expect(InviteCode.format('ABCD-2345'), 'ABCD-2345');
    });

    test('to`liq bo`lmagan kod ham bo`lib yoziladi', () {
      expect(InviteCode.format(''), '');
      expect(InviteCode.format('ab'), 'AB');
      expect(InviteCode.format('abcd'), 'ABCD');
      expect(InviteCode.format('abcde'), 'ABCD-E');
    });
  });

  group('fromScan', () {
    test('panel QR havolasidan kod olinadi', () {
      expect(
        InviteCode.fromScan('https://parvoz.uz/link?code=ABCD2345'),
        'ABCD2345',
      );
      expect(
        InviteCode.fromScan('  https://parvoz.uz/link?code=abcd-2345  '),
        'ABCD2345',
      );
      expect(
        InviteCode.fromScan('https://www.parvoz.uz/link?utm=x&code=abcd2345'),
        'ABCD2345',
      );
      expect(
        InviteCode.fromScan('https://farzandimedu.uz/link?code=ABCD2345'),
        'ABCD2345',
      );
    });

    test('xom kod ham qabul qilinadi', () {
      expect(InviteCode.fromScan('abcd-2345'), 'ABCD2345');
      expect(InviteCode.fromScan('ABCD2345'), 'ABCD2345');
    });

    test('begona sayt, kodsiz yoki yaroqsiz kodli havola — null', () {
      expect(
        InviteCode.fromScan('https://evil.example/link?code=ABCD2345'),
        isNull,
      );
      expect(InviteCode.fromScan('https://parvoz.uz/link'), isNull);
      expect(InviteCode.fromScan('https://parvoz.uz/link?code=XYZ'), isNull);
      expect(InviteCode.fromScan('https://parvoz.uz/link?code=%zz'), isNull);
      expect(InviteCode.fromScan('ftp://parvoz.uz/link?code=ABCD2345'), isNull);
    });

    test('boshqa QR turlari va bo`sh matn — null', () {
      expect(
        InviteCode.fromScan('farzandim://device-link?code=ABCD2345'),
        isNull,
      );
      expect(InviteCode.fromScan(''), isNull);
      expect(InviteCode.fromScan('   '), isNull);
      expect(InviteCode.fromScan('salom dunyo'), isNull);
    });
  });
}
