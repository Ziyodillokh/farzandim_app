// audio_service 1.0.20 da olib tashlandi: u har bir Flutter engine'ga (FGS,
// FCM) ulanib, fon jarayonida ilovaning main()'ini yashirin ikkinchi nusxada
// ishga tushirardi (kill-native-audioservice-headless-main). Audiokitob ilova
// ochiq paytda just_audio bilan ijro etiladi. Qayta qo'shilmasin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Bo'laklab yozilgan — bu faylning o'zi qidiruvga tushmasin.
const _import =
    'package:'
    'audio_service/';

void main() {
  test('lib/ va test/ da audio_service importi yo\'q', () {
    final offenders = [
      for (final dir in ['lib', 'test'])
        for (final file in Directory(dir).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              file.readAsStringSync().contains(_import))
            file.path,
    ];

    expect(offenders, isEmpty);
  });

  test('pubspec va lock faylida audio_service paketi yo\'q', () {
    final dependency = RegExp(r'^\s+audio_service\s*:', multiLine: true);

    expect(
      dependency.hasMatch(File('pubspec.yaml').readAsStringSync()),
      isFalse,
    );
    expect(
      dependency.hasMatch(File('pubspec.lock').readAsStringSync()),
      isFalse,
    );
  });
}
