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

  const QuestionModel({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.timeSeconds = 40,
    this.bonus = 50,
  });
}
