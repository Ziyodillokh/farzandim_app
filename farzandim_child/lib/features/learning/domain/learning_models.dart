// ─────────────────────────────────────────────────────────────────────
// Daily Learning — domen modellari (Growth yangi konsepsiyasi)
// ─────────────────────────────────────────────────────────────────────
//
// Bola tanlagan fanlar bo'yicha kunlik testlar va natijalar xulosasi.
// Hozircha faqat UI uchun (backend keyingi bosqichda) — shu sababli
// modellar immutable va JSON'siz.

/// Maktab fanlari (onboarding'da bola tanlaydi).
enum Subject {
  math,
  english,
  native,
  history,
  biology,
  geography,
  physics,
  chemistry,
  informatics,
  russian;

  /// Tarjima kaliti — `subjects.<name>`.
  String get labelKey => 'subjects.$name';
}

/// Kunlik rejadagi bitta fan: nechta savol.
class DailyPlanItem {
  const DailyPlanItem({required this.subject, required this.questionCount});

  final Subject subject;
  final int questionCount;
}

/// Bugungi testlar rejasi.
class DailyPlan {
  const DailyPlan({required this.items});

  /// Reja yo'q (fan tanlanmagan yoki backend bo'sh).
  static const empty = DailyPlan(items: []);

  final List<DailyPlanItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalQuestions =>
      items.fold(0, (sum, item) => sum + item.questionCount);
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
