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

  group('JsonFieldReader — tur mos kelmasa zaxira qiymat, otmaydi', () {
    const json = <String, dynamic>{
      'name': 'Aziz',
      'empty': '',
      'count': 3,
      'double': 4.7,
      'numeric': ' 12 ',
      'flag': true,
      'at': '2026-10-20T05:00:00.000Z',
      'bad': 'kecha',
      'nested': {'id': 'x'},
      'list': [1, 2],
    };

    test('readString / readStringOrNull', () {
      expect(json.readString('name'), 'Aziz');
      expect(json.readString('count'), '');
      expect(json.readString('missing', fallback: '—'), '—');
      expect(json.readStringOrNull('empty'), isNull);
      expect(json.readStringOrNull('count'), isNull);
    });

    test('readInt / readIntOrNull', () {
      expect(json.readInt('count'), 3);
      expect(json.readInt('double'), 4);
      expect(json.readInt('numeric'), 12);
      expect(json.readInt('name', fallback: -1), -1);
      expect(json.readIntOrNull('missing'), isNull);
    });

    test('readBool, readDateTime, readMapOrNull, readList', () {
      expect(json.readBool('flag'), isTrue);
      expect(json.readBool('name'), isFalse);
      expect(json.readDateTime('at'), DateTime.utc(2026, 10, 20, 5).toLocal());
      expect(json.readDateTime('bad'), isNull);
      expect(json.readDateTime('count'), isNull);
      expect(json.readMapOrNull('nested'), {'id': 'x'});
      expect(json.readMapOrNull('list'), isNull);
      expect(json.readList('list'), [1, 2]);
      expect(json.readList('nested'), isEmpty);
    });

    test('asJsonMap: oddiy Map ham, satr bo`lmagan kalitlar tashlanadi', () {
      expect(asJsonMap(null), isNull);
      expect(asJsonMap('x'), isNull);
      expect(asJsonMap(<Object, Object>{'a': 1, 2: 'b'}), {'a': 1});
    });
  });
}
