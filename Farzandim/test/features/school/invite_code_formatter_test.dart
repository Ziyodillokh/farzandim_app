// Taklif kodi maydoni: katta harf, faqat A–Z/0–9, 8 belgi, "XXXX-XXXX";
// raqamli 6 xonali kod bo'linmaydi ("042913", bosh nol saqlanadi); kursor kod
// belgilariga nisbatan joyida qoladi; yopishtirilgan matndan kod ajratiladi.

import 'package:farzandim/features/school/presentation/invite_code_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _formatter = InviteCodeInputFormatter();

TextEditingValue _type(String text, {int? cursor}) =>
    _formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      ),
    );

void main() {
  test('kichik harf → katta, 4-belgidan keyin "-"', () {
    expect(_type('abcd').text, 'ABCD');
    expect(_type('abcd2').text, 'ABCD-2');
    expect(_type('abcd2345').text, 'ABCD-2345');
  });

  test('bo`shliq, "-" va boshqa belgilar olib tashlanadi', () {
    expect(_type(' ab cd-23 45 ').text, 'ABCD-2345');
    expect(_type('ab!c@d#2345').text, 'ABCD-2345');
    expect(_type('кодAB12').text, 'AB12');
  });

  test('8 belgidan ortig`i kesiladi', () {
    expect(_type('ABCD2345XYZ').text, 'ABCD-2345');
    expect(_type('ABCD-2345-XYZ').text, 'ABCD-2345');
  });

  test('kursor oxirida — formatlangan matn oxirida', () {
    final value = _type('abcd2');
    expect(value.selection, const TextSelection.collapsed(offset: 6));
  });

  test('o`rtadan tahrir — kursor kod belgilari bo`yicha joyida', () {
    // "AB|CD-2345" ga "x" yozildi: "ABX|CD-2345" → "ABXC-D234" (8 belgi).
    final inserted = _type('ABxCD-2345', cursor: 3);
    expect(inserted.text, 'ABXC-D234');
    expect(inserted.selection.baseOffset, 3);

    // "-" dan keyingi belgidan keyin kursor: "ABCD-2|345" → 6.
    final after = _type('ABCD-2345', cursor: 6);
    expect(after.selection.baseOffset, 6);

    // "-" o'chirildi ("ABCD|2345"): kursor 4 — tire qayta qo'yiladi.
    final deletedDash = _type('ABCD2345', cursor: 4);
    expect(deletedDash.text, 'ABCD-2345');
    expect(deletedDash.selection.baseOffset, 4);
  });

  test('yaroqsiz tanlov (selection) — kursor oxirida', () {
    final value = _formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'abcd23'),
    );
    expect(value.text, 'ABCD-23');
    expect(value.selection.baseOffset, 7);
  });

  test('bo`sh matn', () {
    final value = _type('');
    expect(value.text, isEmpty);
    expect(value.selection.baseOffset, 0);
  });

  group('raqamli (6 xonali) kod', () {
    test('raqamlar bo`linmaydi, bosh nol saqlanadi', () {
      expect(_type('0').text, '0');
      expect(_type('0429').text, '0429');
      expect(_type('04291').text, '04291');
      expect(_type('042913').text, '042913');
    });

    test('bo`shliq va chiziqcha olinadi: "042 913", "042-913"', () {
      expect(_type('042 913').text, '042913');
      expect(_type('042-913').text, '042913');
      expect(_type(' 0 4 2 9 1 3 ').text, '042913');
    });

    test('kursor raqamli kodda siljimaydi (tire yo`q)', () {
      expect(_type('042913').selection.baseOffset, 6);
      // "042|913" — o'rtadan yozilgan kursor kod belgilari bo'yicha.
      expect(_type('042913', cursor: 3).selection.baseOffset, 3);
      expect(_type('04291', cursor: 5).selection.baseOffset, 5);
    });

    test('7-raqam kodni vasiy kodi shakliga o`tkazadi', () {
      final value = _type('1234567');
      expect(value.text, '1234-567');
      expect(value.selection.baseOffset, 8);
    });

    test('6 raqamdan keyin harf — aralash kod, tire bilan', () {
      expect(_type('04291a').text, '0429-1A');
    });
  });

  group('yopishtirish', () {
    TextEditingValue paste(String text, {String old = ''}) =>
        _formatter.formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );

    test('xabar ichidagi 6 xonali kod', () {
      final value = paste('Maktab kodi: 042 913. Muddati 24 soat.');
      expect(value.text, '042913');
      expect(value.selection.baseOffset, 6);
    });

    test('xabar ichidagi XXXX-XXXX kod', () {
      final value = paste('Taklif kodi: abcd-2345 (7 kun)');
      expect(value.text, 'ABCD-2345');
      expect(value.selection.baseOffset, 9);
    });

    test('mavjud matn ustiga yopishtirilsa ham kod toza chiqadi', () {
      expect(paste('Kod 042913', old: '12').text, '042913');
    });

    test('toza kod yopishtirilsa — oddiy yo`l', () {
      expect(paste('042913').text, '042913');
      expect(paste('abcd2345').text, 'ABCD-2345');
      expect(paste('ABCD-2345').text, 'ABCD-2345');
    });

    test('kod topilmasa — belgilar oddiy filtrlanadi', () {
      expect(paste('Tel: 998901234567').text, 'TEL9-9890');
    });

    test(
      'tanlangan matn ustiga yopishtirish: uzunlik farqi kichik bo`lsa ham',
      () {
        // "ABCD-2345" (9 belgi) to'liq tanlangan, ustiga 10 belgili xabar
        // yopishtirildi: farq 1, lekin qo'shilgani 10 belgi.
        final value = _formatter.formatEditUpdate(
          const TextEditingValue(
            text: 'ABCD-2345',
            selection: TextSelection(baseOffset: 0, extentOffset: 9),
          ),
          const TextEditingValue(
            text: 'Kod 042913',
            selection: TextSelection.collapsed(offset: 10),
          ),
        );
        expect(value.text, '042913');
        expect(value.selection.baseOffset, 6);
      },
    );

    test('tanlangan matn o`rniga bitta belgi yozilsa — oddiy tahrir', () {
      final value = _formatter.formatEditUpdate(
        const TextEditingValue(
          text: 'ABCD-2345',
          selection: TextSelection(baseOffset: 0, extentOffset: 9),
        ),
        const TextEditingValue(
          text: 'x',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(value.text, 'X');
      expect(value.selection.baseOffset, 1);
    });

    test('harf-faqat kod xabar ichidan: "Kod: ABCD-EFGH"', () {
      expect(paste('Kod: ABCD-EFGH').text, 'ABCD-EFGH');
      expect(paste('Kod ABCDEFGH').text, 'ABCD-EFGH');
    });

    test('bitta belgi yozish xabar sifatida o`qilmaydi', () {
      // Eski matn to'la kod: 9-chi belgi e'tiborsiz, matn o'zgarmaydi.
      final typed = _formatter.formatEditUpdate(
        const TextEditingValue(text: 'ABCD-2345'),
        const TextEditingValue(
          text: 'ABCD-23456',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(typed.text, 'ABCD-2345');
    });
  });
}
