// Ilova ichidagi savollar banki: har fan fayli o'qiladi, tuzilmasi to'g'ri,
// har sinf oralig'i uchun kunlik testga yetarli savol bor.

import 'dart:convert';
import 'dart:io';

import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final subject in Subject.values) {
    test('${subject.name} banki to\'g\'ri', () {
      final file = File('assets/learning/questions/${subject.name}.json');
      final json = jsonDecode(file.readAsStringSync());
      expect((json as Map)['subject'], subject.name);

      final questions = parseQuestionBank(subject, json);
      expect(questions.map((q) => q.id).toSet(), hasLength(questions.length));

      for (final q in questions) {
        expect(q.options, hasLength(4), reason: q.id);
        for (final text in [q.topic, q.prompt, q.explanation, ...q.options]) {
          for (final lang in kLearningLanguages) {
            expect(text.values[lang]?.trim(), isNotEmpty, reason: q.id);
          }
        }
        expect(
          q.options.map((o) => o.of('uz')).toSet(),
          hasLength(4),
          reason: '${q.id}: takror variant',
        );
      }

      // Fan o'qitiladigan har sinf uchun kunlik test to'ladi.
      final middle = questions.where((q) => q.fitsGrade(7)).length;
      expect(middle, greaterThanOrEqualTo(kDailyQuestionCount));
      if (subject.minGrade < 5) {
        expect(
          questions.where((q) => q.fitsGrade(subject.minGrade)),
          isNotEmpty,
        );
      }
    });
  }
}
