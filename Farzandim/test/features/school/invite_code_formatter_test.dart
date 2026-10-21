// Taklif kodi maydoni: katta harf, faqat A–Z/0–9, 8 belgi, "XXXX-XXXX";
// kursor kod belgilariga nisbatan joyida qoladi.

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
}
