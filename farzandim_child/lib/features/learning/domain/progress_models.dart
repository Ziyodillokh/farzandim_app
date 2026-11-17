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

/// Yechilgan bitta test natijasi (server `ResultView`).
class TestResult {
  const TestResult({
    required this.id,
    required this.subject,
    required this.topic,
    required this.correct,
    required this.total,
    required this.date,
    this.isDaily = true,
    this.donEarned = 0,
    this.durationSeconds = 0,
  });

  /// API JSON'idan; buzilgan yozuv bo'lsa `null` (o'tkazib yuboriladi).
  static TestResult? tryFromJson(Object? json) {
    if (json case {
      'id': final String id,
      'subject': final String subjectName,
      'correct': final int correct,
      'total': final int total,
      'date': final String rawDate,
    }) {
      final subject = Subject.fromName(subjectName);
      final date = DateTime.tryParse(rawDate)?.toLocal();
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
      final don = json['donEarned'];
      final seconds = json['durationSeconds'];
      return TestResult(
        id: id,
        subject: subject,
        topic: topic,
        correct: correct,
        total: total,
        date: date,
        isDaily: json['isDaily'] != false,
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

  /// Fan bo'yicha kunlik birinchi urinish (amaliyot emas).
  final bool isDaily;

  /// Shu test uchun berilgan DON.
  final int donEarned;

  /// Yechishga ketgan vaqt.
  final int durationSeconds;

  int get percent => total <= 0 ? 0 : (correct * 100 / total).round();
  ScoreLevel get level => ScoreLevel.of(correct, total);
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
