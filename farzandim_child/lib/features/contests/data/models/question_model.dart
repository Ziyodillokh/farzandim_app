// ─────────────────────────────────────────────────────────────────────
// QuestionModel — konkurs savol-javob bandi
// ─────────────────────────────────────────────────────────────────────

class QuestionModel {
  final String id;
  final String text;
  final List<String> options; // 4 ta variant
  final int correctIndex; // 0..3
  final String? explanation;
  final int timeSeconds;
  final int bonus;

  /// Savol rasmi (ixtiyoriy) — TO'LIQ URL (olympiad-images proxy). Admin savolga
  /// rasm yuklagan bo'lsa keladi; bo'sh bo'lsa rasm ko'rsatilmaydi.
  final String imageUrl;

  const QuestionModel({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.timeSeconds = 40,
    this.bonus = 50,
    this.imageUrl = '',
  });
}
