// ─────────────────────────────────────────────────────────────────────
// Rivojlanish (progress) — domen modellari
// ─────────────────────────────────────────────────────────────────────
//
// "Rivojlanish" sahifasi: haftalik o'sish, fanlar bo'yicha natija,
// so'nggi test natijalari va tavsiya. Daily Learning backend'i bilan
// to'ldiriladi (hozircha preview — `progress_providers.dart`).

import 'package:farzandim_child/features/learning/domain/learning_models.dart';

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
    if (percent >= 80) return ScoreLevel.good;
    if (percent >= 60) return ScoreLevel.medium;
    return ScoreLevel.low;
  }
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
  });

  final String id;
  final Subject subject;

  /// Mavzu ("Arifmetika", "Grammar").
  final String topic;
  final int correct;
  final int total;
  final DateTime date;

  int get percent => total <= 0 ? 0 : (correct * 100 / total).round();
  ScoreLevel get level => ScoreLevel.of(correct, total);
}

/// Bugungi tavsiya — qaysi fandan nechta test ishlash.
class ProgressRecommendation {
  const ProgressRecommendation({
    required this.subject,
    required this.testCount,
  });

  final Subject subject;
  final int testCount;
}
