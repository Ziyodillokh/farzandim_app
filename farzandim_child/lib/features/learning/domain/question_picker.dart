// Adaptiv savol tanlash: bolaning shu fandagi so'nggi natijasiga qarab
// qiyinlik tanlanadi (past → oson, o'rta → o'rta, yuqori → qiyin), yaqinda
// berilgan savollar iloji boricha takrorlanmaydi, sinfga moslari afzal.

import 'dart:math' as math;

import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';

/// So'nggi natijaga mos maqsadli qiyinlik (`null` — hali natija yo'q).
int targetDifficulty(int? recentPercent) {
  if (recentPercent == null) return kMinDifficulty;
  if (recentPercent >= kSuccessPercent) return kMaxDifficulty;
  if (recentPercent >= 60) return 2;
  return kMinDifficulty;
}

/// [pool]dan [count] ta savol: maqsadli qiyinlikka yaqin, sinfga mos va
/// yaqinda ko'rilmaganlari birinchi. Bir kunda bir xil [seed] — bir xil
/// tanlov (testni qayta boshlash savollarni "almashtirmaydi").
/// Natija osondan qiyinga tartiblangan.
List<QuizQuestion> pickQuestions({
  required List<QuizQuestion> pool,
  required int grade,
  required int count,
  required int? recentPercent,
  required Set<String> recentlySeen,
  required int seed,
}) {
  if (pool.isEmpty || count <= 0) return const [];
  final target = targetDifficulty(recentPercent);
  final shuffled = [...pool]..shuffle(math.Random(seed));
  int cost(QuizQuestion q) =>
      q.gradeDistance(grade) * 10 +
      (recentlySeen.contains(q.id) ? 4 : 0) +
      (q.difficulty - target).abs();
  // Barqaror saralash: teng narxlilar aralashtirilgan tartibda qoladi.
  final ranked = [
    for (var i = 0; i < shuffled.length; i++) (i, cost(shuffled[i])),
  ]..sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$1 - b.$1);
  final picked = [for (final (i, _) in ranked.take(count)) shuffled[i]]
    ..sort((a, b) => a.difficulty - b.difficulty);
  return picked;
}

/// Kun + fan uchun barqaror urug' (bir kunda bir xil savollar).
int dailySeed(DateTime day, int subjectIndex) =>
    (day.year * 10000 + day.month * 100 + day.day) * 31 + subjectIndex;
