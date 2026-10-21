// Tarjima fayllari (uz/ru/en) bir xil kalitlarga ega bo'lishi shart:
// yetishmagan kalit ekranda xom "school.errors.x" matni bo'lib chiqadi.
// Barcha qiymatlar bo'sh bo'lmagan satr va `{name}` o'rin-bosarlari uchala
// tilda bir xil. Maktab (`school.*`), Growth (`growth.*`) va Kelajak
// (`kelajak.*`) guruhlari alohida ham tekshiriladi. Maktab to'lov
// matnlarida "qarz" so'zi yo'q; Kelajak matnlarida qat'iy kasb hukmi va
// "100%" yo'q.

import 'dart:convert';
import 'dart:io';

import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_support_card.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/school_push.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _languages = ['uz', 'ru', 'en'];

/// Bildirishnoma sahifasidagi maktab tugmalari yorliqlari (har push turi
/// uchun, kerakli data bilan) — kalit o'zgaruvchida, regex ushlamaydi.
Iterable<String> _schoolPushLabelKeys() sync* {
  for (final type in NotificationType.values) {
    final target = schoolPushTarget(
      AppNotification(
        id: 'n-${type.name}',
        type: type,
        childId: 'kid-1',
        childName: 'Bola',
        title: 'T',
        message: 'M',
        timestamp: DateTime(2026, 10, 20),
        data: const {
          'studentId': 'st-1',
          'announcementId': 'a-1',
          'verificationId': 'v-1',
          'date': '2026-10-20',
        },
      ),
    );
    if (target != null) yield target.labelKey;
  }
}

/// Ichma-ich obyektni "a.b.c" → qiymat ko'rinishiga yoyadi.
Map<String, Object?> _flatten(Map<String, dynamic> node, [String prefix = '']) {
  return {
    for (final entry in node.entries)
      ...switch (entry.value) {
        final Map<String, dynamic> child => _flatten(
          child,
          '$prefix${entry.key}.',
        ),
        final Object? leaf => {'$prefix${entry.key}': leaf},
      },
  };
}

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final flat = {
    for (final lang in _languages)
      lang: _flatten(
        jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
  };
  final reference = flat['uz']!;

  test('uz/ru/en kalitlari bir xil', () {
    for (final lang in _languages.skip(1)) {
      final keys = flat[lang]!.keys.toSet();
      expect(
        reference.keys.toSet().difference(keys),
        isEmpty,
        reason: '$lang da yetishmaydi',
      );
      expect(
        keys.difference(reference.keys.toSet()),
        isEmpty,
        reason: '$lang da ortiqcha',
      );
    }
  });

  test('qiymatlar bo`sh bo`lmagan satr, o`rin-bosarlar bir xil', () {
    for (final key in reference.keys) {
      final values = [for (final lang in _languages) flat[lang]![key]];
      for (final (i, value) in values.indexed) {
        expect(value, isA<String>(), reason: '${_languages[i]}: $key');
        expect((value! as String).trim(), isNotEmpty, reason: key);
      }
      final expected = _placeholders(values.first! as String);
      for (final value in values.skip(1)) {
        expect(_placeholders(value! as String), expected, reason: key);
      }
    }
  });

  for (final group in [
    'school.errors.',
    'growth.subjects.',
    'growth.profile.',
    'growth.noTests.',
    'growth.noProfile.',
    'growth.card.',
    'settings.rows.school.',
    'dashboard.school.',
    'school.home.',
    'school.link.',
    'school.match.',
    'school.attendance.status.',
    'school.announcements.',
    'school.earlyExit.status.',
    'school.payments.',
    'school.verifications.status.',
    'school.mode.',
    'kelajak.card.',
    'kelajak.link.',
    'kelajak.header.',
    'kelajak.interests.',
    'kelajak.careerLab.',
    'kelajak.support.',
    'kelajak.progress.',
    'kelajak.empty.',
    'kelajak.age.',
  ]) {
    test('$group guruhi uchala tilda mavjud', () {
      for (final lang in _languages) {
        expect(
          flat[lang]!.keys.where((k) => k.startsWith(group)),
          isNotEmpty,
          reason: '$lang: $group',
        );
      }
    });
  }

  test('maktab/Growth/Kelajak kodidagi `.tr()` kalitlari tarjimada bor', () {
    // 'a.b.c'.tr( — literal kalitlar (interpolyatsiyali kalit alohida
    // testda: SchoolDayStatus.labelKey).
    final keyPattern = RegExp(
      r"'([a-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)'\s*\.tr\(",
    );
    final files = [
      for (final dir in [
        'lib/features/school',
        'lib/features/growth',
        'lib/features/kelajak',
      ])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      File('lib/features/settings/presentation/screens/settings_screen.dart'),
    ];
    final used = <String>{};
    final missing = <String>{};
    for (final file in files) {
      for (final match in keyPattern.allMatches(file.readAsStringSync())) {
        final key = match.group(1)!;
        used.add(key);
        if (!reference.containsKey(key)) missing.add('${file.path}: $key');
      }
    }
    expect(used, isNotEmpty);
    expect(missing, isEmpty);
  });

  test('interpolyatsiyali kalitlar (holatlar, oy, hafta kunlari, push '
      'tugmalari) bor', () {
    // 7 turdan (eslatmadan tashqari) 6 xil tugma yorlig'i.
    expect(_schoolPushLabelKeys().toSet(), hasLength(6));
    final keys = [
      for (final status in EarlyExitStatus.values) earlyExitStatusKey(status),
      for (final status in VerificationStatus.values)
        verificationStatusKey(status),
      for (final status in SchoolDayStatus.values) status.labelKey,
      for (var month = 1; month <= 12; month++) 'leaderboard.months.$month',
      for (var day = 1; day <= 7; day++) 'dashboard.chart.weekdays.$day',
      ..._schoolPushLabelKeys(),
      for (final days in kGrowthPeriods) growthPeriodLabelKey(days),
      for (final subject in LearningSubject.values) subject.labelKey,
      ...kKelajakTalkTipKeys,
      'kelajak.careerLab.liked',
      'kelajak.careerLab.neutral',
      'kelajak.careerLab.disliked',
      'kelajak.support.titleWatch',
      'kelajak.support.titleSupport',
      'kelajak.age.requiredTitle',
      'kelajak.age.requiredBody',
      'kelajak.age.requiredAction',
      'kelajak.age.outOfRangeTitle',
      'kelajak.age.outOfRangeBody',
      'kelajak.age.outOfRangeAction',
    ];
    for (final key in keys) {
      expect(reference.containsKey(key), isTrue, reason: key);
    }
  });

  test('Kelajak matnlarida qat`iy kasb hukmi va "100%" yo`q', () {
    // Backend `texts-policy.spec.ts` bilan bir xil taqiqlar.
    final verdict = RegExp(
      "bo['‘’]lishing kerak|mos ekansan|100%|должен стать|"
      'тебе нужно стать|you should become|you must become',
      caseSensitive: false,
    );
    for (final lang in _languages) {
      final offending = flat[lang]!.entries.where(
        (e) => e.key.startsWith('kelajak.') && verdict.hasMatch('${e.value}'),
      );
      expect(offending.map((e) => e.key), isEmpty, reason: lang);
    }
  });

  test('maktab matnlarida "qarz" (qarzdorlik) so`zi yo`q', () {
    final debt = RegExp('qarz|долг|задолж|debt', caseSensitive: false);
    for (final lang in _languages) {
      final offending = flat[lang]!.entries.where(
        (e) => e.key.startsWith('school.') && debt.hasMatch('${e.value}'),
      );
      expect(offending.map((e) => e.key), isEmpty, reason: lang);
    }
  });
}
