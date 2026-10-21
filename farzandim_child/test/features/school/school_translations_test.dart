// `school.*` tarjimalari: uch tilda bir xil kalitlar va o'rinbosarlar
// (`{count}`), bo'sh matn yo'q, har bir xato kodi, test turi, LIKERT /
// so'rovnoma bahosi, murojaat mavzusi va holatining, topshiriq turining matni
// bor. Maktab ishlatadigan boshqa bo'limlardagi kalitlar ham uch tilda.

import 'dart:convert';
import 'dart:io';

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/assignment_display.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:flutter_test/flutter_test.dart';

const _languages = ['uz', 'ru', 'en'];

/// Faylning barcha barg kalitlari (`school.hub.title` …) → matn.
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

/// `school` bo'limining barcha barg kalitlari → matn.
Map<String, Object?> _schoolLeaves(Map<String, Object?> all) => {
  for (final entry in all.entries)
    if (entry.key.startsWith('school.')) entry.key: entry.value,
};

/// Maktab sahifalari ishlatadigan boshqa bo'limlardagi kalitlar.
final _relatedKeys = [
  'learn.subjectNotInGrade',
  'learn.checkGrade',
  'donHistory.source.dailyLearning',
  'schedules.schoolModeTitle',
  'schedules.schoolModeHint',
  // `school.assignments.testTitle` ichidagi fan nomi.
  for (final subject in Subject.values) subject.labelKey,
];

void main() {
  final all = {for (final l in _languages) l: _allLeaves(l)};
  final leaves = {for (final l in _languages) l: _schoolLeaves(all[l]!)};

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

  test('uch tilda bir xil o\'rinbosarlar ({count}, {date} …)', () {
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

  test(
    'har bir test turi, baho, mavzu, holat va topshiriq turining matni bor',
    () {
      final keys = [
        for (final kind in PsychKind.values) psychKindLabelKey(kind),
        for (final value in likertValues) likertLabelKey(value),
        for (final value in surveyScaleValues) surveyScaleLabelKey(value),
        for (final topic in CareTopic.values) careTopicLabelKey(topic),
        for (final status in CareRequestStatus.values)
          careStatusLabelKey(status),
        for (final kind in SchoolAssignmentKind.values)
          assignmentKindLabelKey(kind),
      ];
      for (final language in _languages) {
        for (final key in keys) {
          expect(leaves[language], contains(key), reason: '$language $key');
        }
      }
    },
  );

  test('maktab ishlatadigan boshqa kalitlar uch tilda bor', () {
    for (final language in _languages) {
      for (final key in _relatedKeys) {
        final value = all[language]![key];
        expect(value, isA<String>(), reason: '$language $key');
        expect((value! as String).trim(), isNotEmpty, reason: '$language $key');
      }
    }
  });

  test('har bir xato kodining matni bor', () {
    for (final language in _languages) {
      for (final code in SchoolErrorCode.values) {
        expect(
          leaves[language],
          contains(code.messageKey),
          reason: '$language ${code.name}',
        );
      }
    }
  });
}
