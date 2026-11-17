// Maktab fanlari — Daily Learning va Rivojlanish uchun umumiy.

/// Maktab fanlari (onboarding'da bola tanlaydi).
enum Subject {
  math(minGrade: 1),
  english(minGrade: 1),
  native(minGrade: 1),
  history(minGrade: 5),
  biology(minGrade: 5),
  geography(minGrade: 5),
  physics(minGrade: 6),
  chemistry(minGrade: 7),
  informatics(minGrade: 5),
  russian(minGrade: 1);

  const Subject({required this.minGrade});

  /// Shu fan maktabda o'qitila boshlanadigan sinf.
  final int minGrade;

  /// Tarjima kaliti — `subjects.<name>`.
  String get labelKey => 'subjects.$name';

  /// Sinfda o'qitiladimi.
  bool isTaughtIn(int grade) => grade >= minGrade;

  /// Saqlangan nomdan (`math`) — noma'lum bo'lsa `null`.
  static Subject? fromName(String? name) {
    for (final s in Subject.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Sinfda o'qitiladigan fanlar (tartib saqlanadi).
  static List<Subject> forGrade(int grade) => [
    for (final s in Subject.values)
      if (s.isTaughtIn(grade)) s,
  ];
}
