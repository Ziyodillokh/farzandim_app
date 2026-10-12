// iPhone (iOS bola) matnlari — yangi kalitlar uchala tilda (uz/ru/en) mavjud,
// bo'sh emas va `{name}` kabi o'rin-bosarlari bir xil bo'lishi shart.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _keys = [
  'iosChild.howItWorksTitle',
  'iosChild.howItWorksBody',
  'iosChild.screenTimeHint',
  'iosChild.appsHint',
  'iosChild.blockBanner',
  'iosChild.limitBanner',
  'iosChild.uninstallSubtitle',
  'iosChild.permissionLabel',
  'iosChild.permissionOn',
  'iosChild.permissionOff',
  'iosChild.permissionUnknown',
  'rejimlar.iosBlockSwitch',
  'rejimlar.iosBlockHint',
  'rejimlar.iosMinWindow',
  'rejimlar.iosAppsBlocked',
  'rejimlar.iosAppsNotBlocked',
  'rejimlar.iosSheetTitle',
  'rejimlar.appsLabel',
  'rejimlar.updated',
  'rejimlar.deleted',
  'rejimlar.deleteTitle',
  'rejimlar.deleteContent',
  'notifications.actions.openChildSettings',
];

Object? _lookup(Map<String, dynamic> root, String dottedKey) {
  Object? node = root;
  for (final part in dottedKey.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node;
}

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final langs = <String, Map<String, dynamic>>{
    for (final lang in ['uz', 'ru', 'en'])
      lang:
          jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
              as Map<String, dynamic>,
  };

  for (final key in _keys) {
    test('$key — uz/ru/en da bor va bo`sh emas', () {
      for (final entry in langs.entries) {
        final value = _lookup(entry.value, key);
        expect(value, isA<String>(), reason: '${entry.key}: $key yo`q');
        expect((value! as String).trim(), isNotEmpty);
      }
    });
  }

  test('o`rin-bosarlar ({name}) uch tilda bir xil', () {
    for (final key in _keys) {
      final sets = [
        for (final lang in langs.values)
          _placeholders(_lookup(lang, key)! as String),
      ];
      expect(sets[1], sets[0], reason: 'ru: $key');
      expect(sets[2], sets[0], reason: 'en: $key');
    }
  });
}
