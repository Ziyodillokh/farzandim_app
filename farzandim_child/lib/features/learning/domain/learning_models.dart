// ─────────────────────────────────────────────────────────────────────
// Daily Learning — domen modellari (Growth yangi konsepsiyasi)
// ─────────────────────────────────────────────────────────────────────
//
// Bola tanlagan sinf va fanlar, kunlik testlar rejasi va natijalar
// xulosasi. Modellar immutable; saqlanadiganlari JSON'ga ega.

import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

export 'package:farzandim_child/features/learning/domain/subject.dart';

/// Bola tanlay oladigan sinflar.
const kMinGrade = 1;
const kMaxGrade = 11;

/// Kunlik rejaga kiradigan fanlar chegarasi (kuniga juda ko'p bo'lmasin).
const kMinSubjects = 1;
const kMaxSubjects = 5;

/// O'quv profili — sinf va kunlik testlar uchun tanlangan fanlar.
class LearningProfile {
  const LearningProfile({required this.grade, required this.subjects});

  /// JSON'dan; buzilgan / noto'g'ri qiymatlar bo'lsa `null`.
  static LearningProfile? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final grade = json['grade'];
    final names = json['subjects'];
    if (grade is! int || names is! List) return null;
    final subjects = <Subject>[];
    for (final name in names) {
      final subject = Subject.fromName(name is String ? name : null);
      if (subject != null && !subjects.contains(subject)) {
        subjects.add(subject);
      }
    }
    final profile = LearningProfile(
      grade: grade,
      subjects: List.unmodifiable(subjects),
    );
    return profile.isValid ? profile : null;
  }

  final int grade;
  final List<Subject> subjects;

  /// Sinf oralig'ida, fanlar soni chegarada va hammasi shu sinfda o'qitiladi.
  bool get isValid =>
      grade >= kMinGrade &&
      grade <= kMaxGrade &&
      subjects.length >= kMinSubjects &&
      subjects.length <= kMaxSubjects &&
      subjects.toSet().length == subjects.length &&
      subjects.every((s) => s.isTaughtIn(grade));

  Map<String, Object> toJson() => {
    'grade': grade,
    'subjects': [for (final s in subjects) s.name],
  };
}

/// Kunlik rejadagi bitta fan: nechta savol va (bo'lsa) bugungi natija.
class DailyPlanItem {
  const DailyPlanItem({
    required this.subject,
    required this.questionCount,
    this.result,
  });

  final Subject subject;
  final int questionCount;

  /// Bugun shu fan bo'yicha yakunlangan kunlik test.
  final TestResult? result;

  bool get isDone => result != null;
}

/// Bugungi testlar rejasi.
class DailyPlan {
  const DailyPlan({required this.items});

  /// Reja yo'q (fan tanlanmagan).
  static const empty = DailyPlan(items: []);

  final List<DailyPlanItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalQuestions =>
      items.fold(0, (sum, item) => sum + item.questionCount);

  int get doneCount => items.where((i) => i.isDone).length;
  bool get isComplete => items.isNotEmpty && doneCount == items.length;

  /// Navbatdagi yechilmagan fan (`null` — hammasi bajarilgan).
  DailyPlanItem? get nextItem {
    for (final item in items) {
      if (!item.isDone) return item;
    }
    return null;
  }

  /// Rejadagi fan (`null` — rejada yo'q).
  DailyPlanItem? itemFor(Subject subject) {
    for (final item in items) {
      if (item.subject == subject) return item;
    }
    return null;
  }
}

/// So'nggi natijalar xulosasi (bosh sahifa kartasi uchun).
class LearningSummary {
  const LearningSummary({
    required this.solvedQuestions,
    required this.averagePercent,
    required this.recentTestCount,
    this.strongSubject,
    this.strongPercent,
    this.focusSubject,
  });

  /// Hali test yechilmagan.
  static const empty = LearningSummary(
    solvedQuestions: 0,
    averagePercent: 0,
    recentTestCount: 0,
  );

  /// Jami yechilgan savollar.
  final int solvedQuestions;

  /// So'nggi testlardagi o'rtacha natija (0–100).
  final int averagePercent;

  /// O'rtacha hisoblangan testlar soni.
  final int recentTestCount;

  /// Eng yuqori natijali fan va undagi o'rtacha foiz.
  final Subject? strongSubject;
  final int? strongPercent;

  /// Ko'proq mashq qilish tavsiya etilgan fan.
  final Subject? focusSubject;

  bool get hasResults => recentTestCount > 0;
}
