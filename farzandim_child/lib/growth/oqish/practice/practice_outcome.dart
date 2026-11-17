// U08 natija mazmuni (sof hisob): sarlavha, oldingi natija bilan solishtirish,
// yulduzlar va mavzular. Bola faqat o'zining oldingi natijasi bilan solishtiriladi.

/// Natija sarlavhasi darajasi.
enum OutcomeTone { great, good, start }

/// Oldingi safarga nisbatan.
enum OutcomeTrend { first, better, same, lower }

class PracticeOutcome {
  const PracticeOutcome({
    required this.tone,
    required this.trend,
    required this.difference,
    required this.stars,
    this.strongTopic,
    this.reviewTopic,
  });

  final OutcomeTone tone;
  final OutcomeTrend trend;

  /// To'g'ri javoblar farqi (oldingi bilan, mutlaq qiymat).
  final int difference;

  /// 0–3.
  final int stars;

  /// Bu safar hamma savoli to'g'ri bo'lgan mavzu.
  final String? strongTopic;

  /// Xato bo'lgan birinchi mavzu — takrorlash uchun.
  final String? reviewTopic;
}

const kGreatPercent = 80;
const kGoodPercent = 50;

/// Yulduz chegaralari (foiz): 3 — 90+, 2 — 70+, 1 — 40+.
int starsFor(int correct, int total) {
  if (total <= 0) return 0;
  final percent = correct * 100 / total;
  if (percent >= 90) return 3;
  if (percent >= 70) return 2;
  if (percent >= 40) return 1;
  return 0;
}

PracticeOutcome buildOutcome({
  required int correct,
  required int total,
  ({int correct, int total})? previous,
  List<({String topic, bool isCorrect})> answers = const [],
}) {
  final percent = total <= 0 ? 0 : correct * 100 ~/ total;
  final tone = percent >= kGreatPercent
      ? OutcomeTone.great
      : percent >= kGoodPercent
      ? OutcomeTone.good
      : OutcomeTone.start;

  var trend = OutcomeTrend.first;
  var difference = 0;
  if (previous != null && previous.total > 0) {
    // Savollar soni har xil bo'lsa ham to'g'ri solishtirish: 10 talik shkalada.
    final now = correct * 10 / total;
    final before = previous.correct * 10 / previous.total;
    final delta = (now - before).round();
    difference = delta.abs();
    trend = delta > 0
        ? OutcomeTrend.better
        : delta == 0
        ? OutcomeTrend.same
        : OutcomeTrend.lower;
  }

  final byTopic = <String, ({int right, int wrong})>{};
  for (final a in answers) {
    final topic = a.topic.trim();
    if (topic.isEmpty) continue;
    final current = byTopic[topic] ?? (right: 0, wrong: 0);
    byTopic[topic] = a.isCorrect
        ? (right: current.right + 1, wrong: current.wrong)
        : (right: current.right, wrong: current.wrong + 1);
  }
  String? strong;
  String? review;
  for (final entry in byTopic.entries) {
    if (strong == null && entry.value.wrong == 0 && entry.value.right > 0) {
      strong = entry.key;
    }
    if (review == null && entry.value.wrong > 0) review = entry.key;
  }

  return PracticeOutcome(
    tone: tone,
    trend: trend,
    difference: difference,
    stars: starsFor(correct, total),
    strongTopic: strong,
    reviewTopic: review,
  );
}
