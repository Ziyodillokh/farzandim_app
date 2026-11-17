// O'qish markazidagi fanlar ro'yxatlari: asosiy ekrandagi 6 ta fan va
// «Barcha fanlar» — sinfda o'tiladigan hamma fanlar.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';

/// Asosiy ekranda ko'rinadigan fanlar soni (3 × 2 to'r).
const kFeaturedSubjects = 6;

/// Fanlarning ko'rsatish tartibi: avval asosiy, keyin qolganlari.
const kSubjectOrder = [
  Subject.math,
  Subject.native,
  Subject.english,
  Subject.physics,
  Subject.chemistry,
  Subject.biology,
  Subject.history,
  Subject.geography,
  Subject.informatics,
  Subject.russian,
];

/// Sinfda o'tiladigan barcha fanlar (ko'rsatish tartibida).
List<Subject> subjectsForGrade(int grade) => [
  for (final s in kSubjectOrder)
    if (s.isTaughtIn(grade)) s,
];

/// Asosiy ekrandagi 6 ta fan: avval o'quvchi tanlaganlari, so'ng sinfdagi
/// qolgan fanlar tartib bo'yicha. 1–4-sinfda fanlar kamroq — borlari.
List<Subject> featuredSubjects(LearningProfile profile) {
  final chosen = [
    for (final s in profile.subjects)
      if (s.isTaughtIn(profile.grade)) s,
  ];
  return [
    ...chosen,
    for (final s in subjectsForGrade(profile.grade))
      if (!chosen.contains(s)) s,
  ].take(kFeaturedSubjects).toList();
}
