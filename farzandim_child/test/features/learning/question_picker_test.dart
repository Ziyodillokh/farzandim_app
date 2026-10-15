// Adaptiv savol tanlash.

import 'package:farzandim_child/features/learning/domain/question_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'learning_fixtures.dart';

void main() {
  final pool = [
    for (var d = 1; d <= 3; d++)
      for (var i = 0; i < 5; i++) question('d$d-$i', difficulty: d),
    for (var i = 0; i < 6; i++) question('p$i', minGrade: 1, maxGrade: 4),
  ];

  test('maqsadli qiyinlik natijaga qarab', () {
    expect(targetDifficulty(null), 1);
    expect(targetDifficulty(45), 1);
    expect(targetDifficulty(60), 2);
    expect(targetDifficulty(79), 2);
    expect(targetDifficulty(80), 3);
  });

  test('yuqori natija — qiyin savollar birinchi tanlanadi', () {
    final picked = pickQuestions(
      pool: pool,
      grade: 7,
      count: 10,
      recentPercent: 90,
      recentlySeen: const {},
      seed: 1,
    );
    expect(picked, hasLength(10));
    expect(picked.where((q) => q.difficulty == 3), hasLength(5));
    expect(picked.where((q) => q.difficulty == 2), hasLength(5));
    // Osondan qiyinga tartiblangan.
    expect(picked.first.difficulty, 2);
    expect(picked.last.difficulty, 3);
  });

  test('sinfga mos bo\'lmagan savollar oxirgi navbatda', () {
    final picked = pickQuestions(
      pool: pool,
      grade: 3,
      count: 6,
      recentPercent: null,
      recentlySeen: const {},
      seed: 2,
    );
    expect(picked.every((q) => q.id.startsWith('p')), isTrue);
  });

  test('yaqinda ko\'rilganlar takrorlanmaydi (imkon bo\'lsa)', () {
    final seen = {for (var i = 0; i < 5; i++) 'd1-$i'};
    final picked = pickQuestions(
      pool: pool,
      grade: 7,
      count: 5,
      recentPercent: null,
      recentlySeen: seen,
      seed: 3,
    );
    expect(picked.any((q) => seen.contains(q.id)), isFalse);
  });

  test('bir xil urug\' — bir xil tanlov; savol kam bo\'lsa — borlari', () {
    List<String> ids(int seed) => [
      for (final q in pickQuestions(
        pool: pool,
        grade: 7,
        count: 4,
        recentPercent: 70,
        recentlySeen: const {},
        seed: seed,
      ))
        q.id,
    ];
    expect(ids(42), ids(42));
    expect(
      pickQuestions(
        pool: pool.take(3).toList(),
        grade: 7,
        count: 10,
        recentPercent: null,
        recentlySeen: const {},
        seed: 1,
      ),
      hasLength(3),
    );
    expect(
      pickQuestions(
        pool: const [],
        grade: 7,
        count: 10,
        recentPercent: null,
        recentlySeen: const {},
        seed: 1,
      ),
      isEmpty,
    );
  });

  test('kunlik urug\' kun va fanga bog\'liq', () {
    final day = DateTime(2026, 10, 15, 9);
    expect(dailySeed(day, 0), dailySeed(DateTime(2026, 10, 15, 22), 0));
    expect(dailySeed(day, 0), isNot(dailySeed(day, 1)));
    expect(dailySeed(day, 0), isNot(dailySeed(DateTime(2026, 10, 16), 0)));
  });
}
