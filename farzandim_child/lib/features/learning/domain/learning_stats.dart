// Natijalardan hisoblanadigan ko'rsatkichlar — sof funksiyalar (UI va
// providerlardan mustaqil, unit testlar bilan qoplangan). Backend ulanganda
// ham shu hisoblar ishlatilishi mumkin.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';

/// Har fan bo'yicha kunlik savollar soni.
const kDailyQuestionCount = 10;

/// Xulosa va fan natijasi uchun olinadigan so'nggi testlar.
const kSummaryWindow = 7;
const kSubjectWindow = 5;

/// Tavsiya etiladigan mashq hajmi (savol).
const kRecommendedPractice = 10;

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Natijalar foizi (to'g'ri / jami, 0–100); bo'sh bo'lsa `null`.
int? percentOf(Iterable<TestResult> results) {
  var correct = 0;
  var total = 0;
  for (final r in results) {
    correct += r.correct;
    total += r.total;
  }
  return total == 0 ? null : (correct * 100 / total).round();
}

/// Bugungi reja: profil fanlari + bugun yakunlangan natijalar.
/// [results] — yangisi birinchi.
DailyPlan buildDailyPlan(
  LearningProfile? profile,
  List<TestResult> results,
  DateTime now,
) {
  if (profile == null) return DailyPlan.empty;
  final today = results.where((r) => isSameDay(r.date, now));
  return DailyPlan(
    items: [
      for (final subject in profile.subjects)
        DailyPlanItem(
          subject: subject,
          questionCount: kDailyQuestionCount,
          result: today.where((r) => r.subject == subject).firstOrNull,
        ),
    ],
  );
}

/// Fan bo'yicha so'nggi natijalar foizi (`null` — hali yo'q).
int? recentPercentFor(Subject subject, List<TestResult> results) =>
    percentOf(results.where((r) => r.subject == subject).take(kSubjectWindow));

/// Fanlar bo'yicha o'zlashtirish — faqat natijasi borlari, [order] tartibida
/// (profil fanlari birinchi, keyin boshqa yechilganlar).
List<SubjectScore> subjectScores(
  List<TestResult> results, {
  List<Subject> order = const [],
}) {
  final subjects = <Subject>[
    ...order,
    for (final r in results)
      if (!order.contains(r.subject)) r.subject,
  ];
  final seen = <Subject>{};
  return [
    for (final s in subjects)
      if (seen.add(s))
        if (recentPercentFor(s, results) case final int percent)
          SubjectScore(subject: s, percent: percent),
  ];
}

/// Bosh sahifa xulosasi.
LearningSummary summarize(
  List<TestResult> results, {
  List<Subject> order = const [],
}) {
  if (results.isEmpty) return LearningSummary.empty;
  final recent = results.take(kSummaryWindow).toList();
  final scores = subjectScores(results, order: order);
  SubjectScore? strong;
  SubjectScore? weak;
  for (final s in scores) {
    if (strong == null || s.percent > strong.percent) strong = s;
    if (weak == null || s.percent < weak.percent) weak = s;
  }
  final hasFocus =
      weak != null && strong != null && weak.subject != strong.subject;
  return LearningSummary(
    solvedQuestions: results.fold(0, (sum, r) => sum + r.total),
    averagePercent: percentOf(recent) ?? 0,
    recentTestCount: recent.length,
    strongSubject: strong?.subject,
    strongPercent: strong?.percent,
    focusSubject: hasFocus ? weak.subject : null,
  );
}

/// Haftalik rivojlanish: so'nggi 7 kun va undan oldingi 7 kun solishtiriladi.
WeeklyProgress? weeklyProgress(List<TestResult> results, DateTime now) {
  if (results.isEmpty) return null;
  final today = dayOf(now);
  final weekStart = DateTime(today.year, today.month, today.day - 6);
  final prevStart = DateTime(today.year, today.month, today.day - 13);
  final thisWeek = results.where((r) => !r.date.isBefore(weekStart)).toList();
  final prevWeek = results
      .where((r) => !r.date.isBefore(prevStart) && r.date.isBefore(weekStart))
      .toList();
  final thisPercent = percentOf(thisWeek);
  final prevPercent = percentOf(prevWeek);
  var streak = 0;
  for (final r in results) {
    if (r.percent < kSuccessPercent) break;
    streak++;
  }
  return WeeklyProgress(
    growthPercent: thisPercent != null && prevPercent != null
        ? thisPercent - prevPercent
        : 0,
    overallPercent: thisPercent ?? percentOf(results.take(kSummaryWindow)) ?? 0,
    testsThisWeek: thisWeek.length,
    correctAnswers: thisWeek.fold(0, (sum, r) => sum + r.correct),
    successStreak: streak,
  );
}

/// Eng past natijali fan bo'yicha tavsiya (`null` — natija yo'q).
ProgressRecommendation? recommendation(List<SubjectScore> scores) {
  if (scores.isEmpty) return null;
  final weakest = scores.reduce((a, b) => a.percent <= b.percent ? a : b);
  return ProgressRecommendation(
    subject: weakest.subject,
    testCount: kRecommendedPractice,
  );
}

/// Test yechilgan kunlar.
Set<DateTime> activeDays(List<TestResult> results) => {
  for (final r in results) dayOf(r.date),
};

/// Ketma-ket faol kunlar: bugundan (bugun hali yechilmagan bo'lsa —
/// kechadan) orqaga qarab uzluksiz kunlar soni.
int learningStreak(List<TestResult> results, DateTime now) {
  final days = activeDays(results);
  var day = dayOf(now);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// Bir kunning natijalari (yangisi birinchi).
List<TestResult> resultsOn(List<TestResult> results, DateTime day) =>
    results.where((r) => isSameDay(r.date, day)).toList();
