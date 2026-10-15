// ─────────────────────────────────────────────────────────────────────
// Rivojlanish (progress) — domen modellari
// ─────────────────────────────────────────────────────────────────────
//
// "Rivojlanish" sahifasi: haftalik o'sish, fanlar bo'yicha natija,
// so'nggi test natijalari va tavsiya. Qiymatlar `learning_stats.dart`dagi
// sof funksiyalar bilan natijalardan hisoblanadi.

import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';

/// Muvaffaqiyatli natija chegarasi (foiz).
const kSuccessPercent = 80;

/// Haftalik rivojlanish xulosasi.
class WeeklyProgress {
  const WeeklyProgress({
    required this.growthPercent,
    required this.overallPercent,
    required this.testsThisWeek,
    required this.correctAnswers,
    required this.successStreak,
  });

  /// O'tgan haftaga nisbatan o'zgarish (manfiy bo'lishi mumkin).
  final int growthPercent;

  /// Umumiy natija (0–100).
  final int overallPercent;

  /// Bu hafta yechilgan testlar.
  final int testsThisWeek;

  /// Bu haftadagi to'g'ri javoblar soni.
  final int correctAnswers;

  /// Ketma-ket muvaffaqiyatli (≥ 80%) testlar.
  final int successStreak;
}

/// Fan bo'yicha o'zlashtirish.
class SubjectScore {
  const SubjectScore({required this.subject, required this.percent});

  final Subject subject;

  /// 0–100.
  final int percent;
}

/// Natija darajasi — ranglar va saralash uchun.
enum ScoreLevel {
  /// ≥ 80%.
  good,

  /// 60–79%.
  medium,

  /// < 60%.
  low;

  static ScoreLevel of(int correct, int total) {
    if (total <= 0) return ScoreLevel.low;
    final percent = correct * 100 / total;
    if (percent >= kSuccessPercent) return ScoreLevel.good;
    if (percent >= 60) return ScoreLevel.medium;
    return ScoreLevel.low;
  }
}

/// Bitta savolga berilgan javob.
class QuizAnswer {
  const QuizAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
  });

  static QuizAnswer? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['q'];
    final selected = json['s'];
    final correct = json['c'];
    if (id is! String || selected is! int || correct is! bool) return null;
    return QuizAnswer(
      questionId: id,
      selectedIndex: selected,
      isCorrect: correct,
    );
  }

  final String questionId;
  final int selectedIndex;
  final bool isCorrect;

  Map<String, Object> toJson() => {
    'q': questionId,
    's': selectedIndex,
    'c': isCorrect,
  };
}

/// Yechilgan bitta test natijasi.
class TestResult {
  const TestResult({
    required this.id,
    required this.subject,
    required this.topic,
    required this.correct,
    required this.total,
    required this.date,
    this.answers = const [],
    this.donEarned = 0,
    this.durationSeconds = 0,
  });

  /// JSON'dan; buzilgan yozuv bo'lsa `null` (o'tkazib yuboriladi).
  static TestResult? tryFromJson(Object? json) {
    if (json case {
      'id': final String id,
      'subject': final String subjectName,
      'correct': final int correct,
      'total': final int total,
      'date': final String rawDate,
    }) {
      final subject = Subject.fromName(subjectName);
      final date = DateTime.tryParse(rawDate);
      if (subject == null ||
          date == null ||
          total <= 0 ||
          correct < 0 ||
          correct > total) {
        return null;
      }
      LocalizedText topic;
      try {
        topic = LocalizedText.fromJson(json['topic']);
      } on FormatException {
        topic = LocalizedText.same('');
      }
      final rawAnswers = json['answers'];
      final don = json['don'];
      final seconds = json['seconds'];
      return TestResult(
        id: id,
        subject: subject,
        topic: topic,
        correct: correct,
        total: total,
        date: date,
        answers: [
          if (rawAnswers is List)
            for (final a in rawAnswers) ?QuizAnswer.tryFromJson(a),
        ],
        donEarned: don is int ? don : 0,
        durationSeconds: seconds is int ? seconds : 0,
      );
    }
    return null;
  }

  final String id;
  final Subject subject;

  /// Mavzu ("Arifmetika", "Grammar") — har tilda.
  final LocalizedText topic;
  final int correct;
  final int total;

  /// Yakunlangan vaqt (mahalliy).
  final DateTime date;

  /// Savolma-savol javoblar (ko'rib chiqish uchun); eski yozuvlarda bo'sh.
  final List<QuizAnswer> answers;

  /// Shu test uchun berilgan DON.
  final int donEarned;

  /// Yechishga ketgan vaqt.
  final int durationSeconds;

  int get percent => total <= 0 ? 0 : (correct * 100 / total).round();
  ScoreLevel get level => ScoreLevel.of(correct, total);
  bool get canReview => answers.isNotEmpty;

  Map<String, Object> toJson() => {
    'id': id,
    'subject': subject.name,
    'topic': topic.toJson(),
    'correct': correct,
    'total': total,
    'date': date.toIso8601String(),
    'answers': [for (final a in answers) a.toJson()],
    'don': donEarned,
    'seconds': durationSeconds,
  };
}

/// Bugungi tavsiya — qaysi fandan nechta savol ishlash.
class ProgressRecommendation {
  const ProgressRecommendation({
    required this.subject,
    required this.testCount,
  });

  final Subject subject;
  final int testCount;
}
