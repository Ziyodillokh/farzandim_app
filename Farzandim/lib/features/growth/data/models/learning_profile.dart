// ─────────────────────────────────────────────────────────────────────
// LearningProfile — bolaning sinfi va kunlik testlar fanlari
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET|PUT /api/children/:childId/learning/profile → `{profile}`.
// Xulosa (`/learning/summary`) ham `profile`ni (`updatedAt`siz) beradi.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:flutter/foundation.dart';

@immutable
class LearningProfile {
  const LearningProfile({
    required this.grade,
    required this.subjects,
    this.updatedAt,
  });

  /// `{grade, subjects, updatedAt?}`; obyekt emas yoki sinf yo'q → `null`.
  /// Noma'lum fan `unknown` bo'ladi, takrorlar bir marta olinadi.
  static LearningProfile? tryParse(Object? raw) {
    final json = asJsonMap(raw);
    final grade = json?.readIntOrNull('grade');
    if (json == null || grade == null) return null;
    final subjects = <LearningSubject>{
      for (final name in json.readList('subjects'))
        LearningSubject.fromApi(name),
    };
    return LearningProfile(
      grade: grade,
      subjects: List.unmodifiable(subjects),
      updatedAt: json.readDateTime('updatedAt'),
    );
  }

  final int grade;
  final List<LearningSubject> subjects;
  final DateTime? updatedAt;

  /// Backend qoidalari: sinf 1–11, 1–5 ta takrorlanmas ma'lum fan va
  /// hammasi shu sinfda o'qitiladi.
  bool get isValid =>
      grade >= kMinLearningGrade &&
      grade <= kMaxLearningGrade &&
      subjects.length >= kMinLearningSubjects &&
      subjects.length <= kMaxLearningSubjects &&
      subjects.toSet().length == subjects.length &&
      subjects.every((s) => s.isTaughtIn(grade));

  /// `PUT /learning/profile` tanasi (`unknown` yuborilmaydi).
  Map<String, Object> toJson() => {
    'grade': grade,
    'subjects': [
      for (final s in subjects)
        if (s != LearningSubject.unknown) s.name,
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is LearningProfile &&
      other.grade == grade &&
      listEquals(other.subjects, subjects) &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(grade, Object.hashAll(subjects), updatedAt);
}
