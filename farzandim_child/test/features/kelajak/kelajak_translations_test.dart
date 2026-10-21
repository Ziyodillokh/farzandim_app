// `kelajak.*` tarjimalari: uch tilda bir xil kalitlar va o'rinbosarlar,
// bo'sh matn yo'q, har bir xato kodi va holatning matni bor, kasb bo'yicha
// qat'iy hukm va foiz iboralari yo'q (docs/KELAJAK-REJA.md §3 siyosati).

import 'dart:convert';
import 'dart:io';

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:flutter_test/flutter_test.dart';

const _languages = ['uz', 'ru', 'en'];

/// Kelajak sahifalari ishlatadigan boshqa bo'limlardagi kalitlar.
const _relatedKeys = [
  'learn.questionOf',
  'common.close',
  'common.retry',
  'common.back',
  'progress.seeAll',
];

/// Taqiqlangan iboralar (server matnlari siyosati bilan bir xil).
const _forbidden = [
  'bo\'lishing kerak',
  'bo‘lishing kerak',
  'mos ekansan',
  'tashxis',
  'должен стать',
  'тебе нужно стать',
  'you should become',
  'you must become',
  '100%',
];

Map<String, Object?> _allLeaves(String language) {
  final file = File('assets/translations/$language.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final leaves = <String, Object?>{};
  void walk(Object? node, String path) {
    if (node is Map<String, Object?>) {
      node.forEach(
        (key, value) => walk(value, path.isEmpty ? key : '$path.$key'),
      );
    } else {
      leaves[path] = node;
    }
  }

  walk(json, '');
  return leaves;
}

void main() {
  final all = {for (final l in _languages) l: _allLeaves(l)};
  final leaves = {
    for (final l in _languages)
      l: {
        for (final e in all[l]!.entries)
          if (e.key.startsWith('kelajak.')) e.key: e.value,
      },
  };

  test('uch tilda bir xil kalitlar', () {
    final uz = leaves['uz']!.keys.toSet();
    expect(uz, isNotEmpty);
    for (final language in _languages) {
      expect(leaves[language]!.keys.toSet(), uz, reason: language);
    }
  });

  test('har bir matn bo\'sh bo\'lmagan satr', () {
    for (final language in _languages) {
      leaves[language]!.forEach((key, value) {
        expect(value, isA<String>(), reason: '$language $key');
        expect((value! as String).trim(), isNotEmpty, reason: '$language $key');
      });
    }
  });

  test('uch tilda bir xil o\'rinbosarlar', () {
    final placeholder = RegExp(r'\{(\w*)\}');
    Set<String> namesOf(Object? text) => {
      for (final m in placeholder.allMatches(text! as String)) m[1]!,
    };
    for (final key in leaves['uz']!.keys) {
      final uz = namesOf(leaves['uz']![key]);
      for (final language in _languages) {
        expect(namesOf(leaves[language]![key]), uz, reason: '$language $key');
      }
    }
  });

  test('har bir xato kodi, holat va tugmaning matni bor', () {
    final keys = [
      for (final code in KelajakErrorCode.values) kelajakErrorKey(code),
      for (final state in KelajakDayState.values) kelajakStatusKey(state),
      for (final state in [...KelajakDayState.values, null])
        kelajakActionKey(state),
    ];
    for (final language in _languages) {
      for (final key in keys) {
        expect(leaves[language], contains(key), reason: '$language $key');
      }
    }
  });

  test('boshqa bo\'limlardagi kalitlar uch tilda bor', () {
    for (final language in _languages) {
      for (final key in _relatedKeys) {
        expect(all[language]![key], isA<String>(), reason: '$language $key');
      }
    }
  });

  test('qat\'iy kasb hukmi va foiz iboralari yo\'q', () {
    for (final language in _languages) {
      leaves[language]!.forEach((key, value) {
        final text = (value! as String).toLowerCase();
        for (final phrase in _forbidden) {
          expect(text.contains(phrase), isFalse, reason: '$language $key');
        }
      });
    }
  });
}
