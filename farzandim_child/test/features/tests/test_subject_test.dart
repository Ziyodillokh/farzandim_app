// Testlar sahifasi — fan bo'yicha guruhlash va qidiruv mantig'i.

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/tests/domain/test_subject.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ContestModel _test(
  String id,
  String soha, {
  bool active = true,
  int bonus = 25,
  String? title,
}) => ContestModel(
  id: id,
  title: title ?? '$soha testi',
  description: '',
  soha: soha,
  ishtirokchilarSoni: 0,
  deadline: DateTime(2026, 12, 31),
  isActive: active,
  placeholderColor: Colors.blue,
  placeholderIcon: Icons.quiz,
  bonus: bonus,
  savollarSoni: 10,
  vaqtChegarasiDaq: 15,
);

void main() {
  group('groupTestsBySubject', () {
    test('turlicha yozilgan fan nomlari bitta guruhga tushadi', () {
      final groups = groupTestsBySubject([
        _test('1', 'Matematika 8-sinf'),
        _test('2', 'matematika'),
        _test('3', 'Algebra'),
        _test('4', 'Ingliz tili'),
      ]);

      expect(groups.map((g) => g.key), ['matematika', 'ingliz']);
      expect(groups.first.count, 3);
    });

    test('maketdagi tartib: Ilmiy-ommabop, Matematika, Ingliz…; '
        'notanishlari oxirida alifbo bo\'yicha', () {
      final groups = groupTestsBySubject([
        _test('1', 'Biologiya'),
        _test('2', 'Zoologiya'),
        _test('3', 'Ilmiy-ommabop'),
        _test('4', 'Astronomiya'),
        _test('5', 'Matematika'),
      ]);

      expect(groups.map((g) => g.key), [
        'ilmiy',
        'matematika',
        'biologiya',
        'astronomiya',
        'zoologiya',
      ]);
      expect(groups.first.fallbackLabel, 'Ilmiy-ommabop');
    });

    test('faol testlar avval; DON faqat faol testlardan yig\'iladi', () {
      final group = groupTestsBySubject([
        _test('old', 'Tarix', active: false, bonus: 100),
        _test('a', 'Tarix', bonus: 30),
        _test('b', 'Tarix', bonus: 20),
      ]).single;

      expect(group.tests.map((t) => t.id), ['a', 'b', 'old']);
      expect(group.availableReward, 50);
    });

    test('fani yozilmagan test "Aralash" guruhiga tushadi', () {
      final groups = groupTestsBySubject([
        _test('1', '   '),
        _test('2', 'Aralash'),
      ]);
      expect(groups.single.key, mixedSubjectKey);
      expect(groups.single.count, 2);
    });

    test('"O‘zbek tili" (U+2018) ham Ona tili guruhiga tushadi', () {
      final groups = groupTestsBySubject([
        _test('1', 'O‘zbek tili'),
        _test('2', 'Ona tili'),
      ]);
      expect(groups.single.key, 'ona_tili');
    });

    test('rus tili kunlik reja kaliti bilan mos', () {
      final group = groupTestsBySubject([_test('1', 'Rus tili')]).single;
      expect(group.key, subjectTestKey(Subject.russian));
    });
  });

  group('searchTests', () {
    final tests = [
      _test('1', 'Ona tili', title: "O'zbek tili qoidalari"),
      _test('2', 'Matematika', title: 'Kasrlar'),
      _test('3', 'Ingliz tili', title: 'Present Simple'),
    ];

    test('sarlavha va fan nomi bo\'yicha, registrsiz', () {
      expect(searchTests(tests, 'KASR').map((t) => t.id), ['2']);
      expect(searchTests(tests, 'ingliz').map((t) => t.id), ['3']);
    });

    test('apostrof turlari farq qilmaydi (o‘ / oʻ / o\')', () {
      expect(searchTests(tests, 'o‘zbek').map((t) => t.id), ['1']);
      expect(searchTests(tests, 'oʻzbek').map((t) => t.id), ['1']);
    });

    test('bo\'sh so\'rov — natija yo\'q', () {
      expect(searchTests(tests, '   '), isEmpty);
    });
  });

  test('kunlik reja fanlari testlar kalitiga mos keladi', () {
    expect(subjectTestKey(Subject.math), 'matematika');
    expect(subjectTestKey(Subject.english), 'ingliz');
    expect(subjectTestKey(Subject.native), 'ona_tili');
    expect(subjectLabelKey('matematika'), 'subjects.math');
    expect(subjectLabelKey('ilmiy'), isNull);
  });
}
