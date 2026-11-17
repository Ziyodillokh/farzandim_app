// Maktab taklif kodi: backend `redeemSchema` bilan bir xil normallashtirish,
// 8 belgili vasiy kodi ("XXXX-XXXX") va 6 xonali raqamli o'quvchi kodi
// ("042913", bosh nol saqlanadi), panel QR havolasidan kod olish.

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

    test('raqamli kodda bosh nol saqlanadi (satr, son emas)', () {
      expect(InviteCode.normalize('042 913'), '042913');
      expect(InviteCode.normalize(' 000-123 '), '000123');
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

  group('6 xonali o`quvchi kodi', () {
    test('6 ta raqam — to`g`ri (bosh nol bilan ham)', () {
      for (final code in ['042913', '000000', '012345', '999999', '123456']) {
        expect(InviteCode.isStudentCode(code), isTrue, reason: code);
        expect(InviteCode.isGuardianCode(code), isFalse, reason: code);
        expect(InviteCode.isValid(code), isTrue, reason: code);
      }
    });

    test('bo`shliq va chiziqcha bilan yozilgan — to`g`ri', () {
      expect(InviteCode.isValid('042 913'), isTrue);
      expect(InviteCode.isValid(' 042-913 '), isTrue);
      expect(InviteCode.isStudentCode('042 913'), isTrue);
    });

    test('5 yoki 7 raqam, harf aralash, boshqa belgi — rad etiladi', () {
      for (final code in ['04291', '0429133', '04291A', 'ABCDEF', '04_913']) {
        expect(InviteCode.isStudentCode(code), isFalse, reason: code);
        expect(InviteCode.isValid(code), isFalse, reason: code);
      }
    });

    test('Arab-hind va to`liq kenglikdagi raqamlar qabul qilinmaydi', () {
      expect(
        InviteCode.isValid('\u0660\u0664\u0662\u0669\u0661\u0663'),
        isFalse,
      );
      expect(
        InviteCode.isValid('\uFF10\uFF14\uFF12\uFF19\uFF11\uFF13'),
        isFalse,
      );
    });

    test('8 ta raqamdan iborat vasiy kodi hamon to`g`ri', () {
      expect(InviteCode.isGuardianCode('23456789'), isTrue);
      expect(InviteCode.isStudentCode('23456789'), isFalse);
      expect(InviteCode.isValid('2345-6789'), isTrue);
    });

    test('isNumericInput: bo`sh yoki faqat raqam', () {
      expect(InviteCode.isNumericInput(''), isTrue);
      expect(InviteCode.isNumericInput('042'), isTrue);
      expect(InviteCode.isNumericInput('042 913'), isTrue);
      expect(InviteCode.isNumericInput('04A'), isFalse);
      expect(InviteCode.isNumericInput('abcd'), isFalse);
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

    test('raqamli kod (≤ 6 raqam) bo`linmaydi, bosh nol saqlanadi', () {
      expect(InviteCode.format('0'), '0');
      expect(InviteCode.format('0429'), '0429');
      expect(InviteCode.format('04291'), '04291');
      expect(InviteCode.format('042913'), '042913');
      expect(InviteCode.format('042-913'), '042913');
    });

    test('7–8 raqam — vasiy kodi kabi bo`linadi', () {
      expect(InviteCode.format('1234567'), '1234-567');
      expect(InviteCode.format('23456789'), '2345-6789');
    });

    test('raqam va harf aralash kod avvalgidek bo`linadi', () {
      expect(InviteCode.format('04291a'), '0429-1A');
    });
  });

  group('matn ichidan kod (yopishtirish)', () {
    test('oddiy kod "xabar" emas', () {
      for (final text in ['042913', '042 913', 'abcd-2345', 'ABCD2345', '']) {
        expect(InviteCode.looksLikeMessage(text), isFalse, reason: text);
      }
    });

    test('ortiqcha so`z yoki belgi — xabar', () {
      expect(InviteCode.looksLikeMessage('Kod: 042913'), isTrue);
      expect(InviteCode.looksLikeMessage('ABCD2345XYZ'), isTrue);
      expect(InviteCode.looksLikeMessage('ab!c'), isTrue);
    });

    test('6 xonali kod xabar ichidan olinadi', () {
      expect(
        InviteCode.extract('Maktab kodi: 042913. Muddati 24 soat.'),
        '042913',
      );
      expect(InviteCode.extract('Kod 042 913 (24 soat)'), '042913');
      expect(InviteCode.extract('kod:042-913!'), '042913');
    });

    test('XXXX-XXXX xabar ichidan olinadi (raqami bor)', () {
      expect(InviteCode.extract('Taklif kodi: abcd-2345, 7 kun'), 'ABCD2345');
      expect(InviteCode.extract('Kod ABCD2345.'), 'ABCD2345');
    });

    test('harf-faqat kod: atrofdagi so`zlar e`tiborga olinmaydi', () {
      // Kodda raqam yo'q (taxminan 10% kod shunday) — oldin "KODA-BCDE" bo'lib
      // qolardi.
      expect(InviteCode.extract('Kod: ABCD-EFGH'), 'ABCDEFGH');
      expect(InviteCode.extract('Kod ABCDEFGH (7 kun)'), 'ABCDEFGH');
      expect(InviteCode.extract('Taklif kodi: abcd-efgh.'), 'ABCDEFGH');
      expect(InviteCode.extract('Kod: ABCD-EFGH yoki 042913'), 'ABCDEFGH');
    });

    test('harf-faqat: oddiy so`zlar va I/O harfli so`zlar kod emas', () {
      // Kod alifbosida I va O yo'q.
      expect(InviteCode.extract('TOSHKENT shahri'), isNull);
      expect(InviteCode.extract('Kod: SALOMLAR'), isNull);
      // Yopishgan variant faqat bosh harflarda; so'z emas.
      expect(InviteCode.extract('Assalomu alaykum'), isNull);
      expect(InviteCode.extract('kod: abcdefgh'), isNull);
      // 9 harf — 8 belgili kod emas.
      expect(InviteCode.extract('Kod: ABCDEFGHJ'), isNull);
      expect(InviteCode.extract('Kod: ABCD EFGH'), isNull);
    });

    test('birinchi uchragan kod tanlanadi', () {
      expect(InviteCode.extract('042913 yoki ABCD-2345'), '042913');
      expect(InviteCode.extract('ABCD-2345 yoki 042913'), 'ABCD2345');
    });

    test('uzun raqam, oddiy so`z va telefon — kod emas', () {
      expect(InviteCode.extract('Tel: 998901234567'), isNull);
      expect(InviteCode.extract('Assalomu alaykum'), isNull);
      expect(InviteCode.extract('Assalomu 5 martta'), isNull);
      expect(InviteCode.extract('1234567'), isNull);
      expect(InviteCode.extract(''), isNull);
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

    test('parseScan: havola `fromLink`, xom kod — yo`q', () {
      // Faqat havola (panel chiqargan QR) darrov yuboriladi.
      expect(InviteCode.parseScan('https://parvoz.uz/link?code=042913'), (
        code: '042913',
        fromLink: true,
      ));
      expect(
        InviteCode.parseScan('https://farzandimedu.uz/link?code=abcd-2345'),
        (code: 'ABCD2345', fromLink: true),
      );
      // Xom kod istalgan begona QR bo'lishi mumkin: faqat maydonga yoziladi.
      expect(InviteCode.parseScan('042913'), (code: '042913', fromLink: false));
      expect(InviteCode.parseScan(' abcd-2345 '), (
        code: 'ABCD2345',
        fromLink: false,
      ));
    });

    test('parseScan: begona sayt, kodsiz havola va bo`sh matn — null', () {
      expect(
        InviteCode.parseScan('https://evil.example/link?code=042913'),
        isNull,
      );
      expect(InviteCode.parseScan('https://parvoz.uz/link?code=12'), isNull);
      expect(InviteCode.parseScan('https://parvoz.uz/link'), isNull);
      expect(InviteCode.parseScan('   '), isNull);
      expect(InviteCode.parseScan('salom'), isNull);
    });

    test('6 xonali kod: xom va havola ichida (bosh nol saqlanadi)', () {
      expect(InviteCode.fromScan('042913'), '042913');
      expect(InviteCode.fromScan(' 042-913 '), '042913');
      expect(
        InviteCode.fromScan('https://parvoz.uz/link?code=042913'),
        '042913',
      );
      expect(InviteCode.fromScan('https://parvoz.uz/link?code=0429'), isNull);
      expect(InviteCode.fromScan('0429133'), isNull);
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

  group('fromLinkParam (deep link `/link?code=`)', () {
    test('to`g`ri kodni normallashtiradi', () {
      expect(InviteCode.fromLinkParam('abcd-2345'), 'ABCD2345');
      expect(InviteCode.fromLinkParam(' 042 913 '), '042913');
    });

    test('bo`sh, yaroqsiz yoki begona qiymat — null', () {
      expect(InviteCode.fromLinkParam(null), isNull);
      expect(InviteCode.fromLinkParam(''), isNull);
      expect(InviteCode.fromLinkParam('12345'), isNull);
      expect(InviteCode.fromLinkParam('<script>'), isNull);
    });

    test('panel QR havolasi (farzandimedu.uz) ishonchli', () {
      final scan = InviteCode.parseScan(
        'https://farzandimedu.uz/link?code=ABCD2345',
      );
      expect(scan?.code, 'ABCD2345');
      expect(scan?.fromLink, isTrue);
    });
  });
}
