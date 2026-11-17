// `g5.*` tarjimalari: uch tilda bir xil kalitlar, bo'sh matn yo'q va o'zbekcha
// matnda oʻ/gʻ uchun to'g'ri belgi (U+02BB), oddiy apostrof emas.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['uz', 'ru', 'en'];

Map<String, String> _g5Leaves(String language) {
  final json =
      jsonDecode(File('assets/translations/$language.json').readAsStringSync())
          as Map<String, Object?>;
  final leaves = <String, String>{};
  void walk(Object? node, String path) {
    if (node is Map<String, Object?>) {
      node.forEach((key, value) => walk(value, '$path.$key'));
    } else {
      leaves[path] = node! as String;
    }
  }

  walk(json['g5'], 'g5');
  return leaves;
}

void main() {
  final leaves = {for (final l in _languages) l: _g5Leaves(l)};

  test('uch tilda bir xil kalitlar', () {
    final uz = leaves['uz']!.keys.toSet();
    expect(uz, isNotEmpty);
    for (final language in _languages) {
      expect(leaves[language]!.keys.toSet(), uz, reason: language);
    }
  });

  test('bo\'sh matn yo\'q', () {
    for (final language in _languages) {
      leaves[language]!.forEach(
        (key, value) =>
            expect(value.trim(), isNotEmpty, reason: '$language $key'),
      );
    }
  });

  test('o\'zbekcha matnda oddiy apostrof ishlatilmaydi', () {
    leaves['uz']!.forEach((key, value) {
      expect(
        value.contains("'"),
        isFalse,
        reason: '$key: «$value» — oʻ/gʻ uchun ʻ, tutuq uchun ʼ',
      );
      expect(value.contains('‘'), isFalse, reason: key);
    });
  });
}
