// parseListSafely — bitta buzuq element ro'yxatni yiqitmasligi kerak.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  _Item(this.id);

  // JSON'dan yasovchi named constructor — tear-off sifatida uzatiladi.
  factory _Item.fromJson(Map<String, dynamic> json) =>
      _Item(json['id'] as int);

  final int id;
}

void main() {
  group('parseListSafely', () {
    test("to'g'ri elementlar parse bo'ladi", () {
      final out = parseListSafely(
        [
          {'id': 1},
          {'id': 2},
        ],
        _Item.fromJson,
      );
      expect(out.map((e) => e.id), [1, 2]);
    });

    test('buzuq element TASHLANADI, qolgani saqlanadi', () {
      final out = parseListSafely(
        [
          {'id': 1},
          {'id': 'buzuq-string'}, // as int yiqiladi
          {'id': 3},
        ],
        _Item.fromJson,
      );
      expect(out.map((e) => e.id), [1, 3]);
    });

    test('Map bo`lmagan elementlar tashlanadi', () {
      final out = parseListSafely(
        [
          'string',
          42,
          null,
          {'id': 7},
        ],
        _Item.fromJson,
      );
      expect(out.single.id, 7);
    });

    test("bo'sh ro'yxat — bo'sh natija", () {
      expect(parseListSafely(const [], _Item.fromJson), isEmpty);
    });

    test('hammasi buzuq — bo`sh natija (exception YO`Q)', () {
      expect(
        parseListSafely(
          [
            {'id': 'a'},
            {'id': 'b'},
          ],
          _Item.fromJson,
        ),
        isEmpty,
      );
    });
  });
}
