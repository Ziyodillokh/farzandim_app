// ─────────────────────────────────────────────────────────────────────
// LearningSubject — Growth (kunlik testlar) fanlari, ota-ona ko'rinishi
// ─────────────────────────────────────────────────────────────────────
//
// Backend `learning/domain/subjects.ts` va bola ilovasidagi `Subject` bilan
// bir xil ro'yxat va "qaysi sinfdan o'qitiladi" qoidasi.

/// Sinf chegarasi (backend `MIN_GRADE` / `MAX_GRADE`).
const int kMinLearningGrade = 1;
const int kMaxLearningGrade = 11;

/// Profildagi fanlar soni chegarasi (backend `MIN_SUBJECTS` / `MAX_SUBJECTS`).
const int kMinLearningSubjects = 1;
const int kMaxLearningSubjects = 5;

/// Growth xulosasi davrlari (kun) — backend faqat shularni qabul qiladi.
const List<int> kGrowthPeriods = [7, 30];

enum LearningSubject {
  math(minGrade: 1),
  english(minGrade: 1),
  native(minGrade: 1),
  history(minGrade: 5),
  biology(minGrade: 5),
  geography(minGrade: 5),
  physics(minGrade: 6),
  chemistry(minGrade: 7),
  informatics(minGrade: 5),
  russian(minGrade: 1),

  /// Ilova bilmaydigan (yangi) fan — ko'rsatiladi, lekin tanlanmaydi.
  unknown(minGrade: kMaxLearningGrade + 1);

  const LearningSubject({required this.minGrade});

  /// Shu fan maktabda o'qitila boshlanadigan sinf.
  final int minGrade;

  /// Tarjima kaliti — `growth.subjects.<name>`.
  String get labelKey => 'growth.subjects.$name';

  /// Shu sinfda o'qitiladimi (`unknown` — hech qachon).
  bool isTaughtIn(int grade) => this != unknown && grade >= minGrade;

  /// API nomidan (`math`); noma'lum → [unknown].
  static LearningSubject fromApi(Object? raw) {
    for (final subject in values) {
      if (subject != unknown && subject.name == raw) return subject;
    }
    return unknown;
  }

  /// Sinfda o'qitiladigan fanlar (tartib saqlanadi).
  static List<LearningSubject> forGrade(int grade) => List.unmodifiable([
    for (final subject in values)
      if (subject.isTaughtIn(grade)) subject,
  ]);
}
