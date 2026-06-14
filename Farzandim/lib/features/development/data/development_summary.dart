// ─────────────────────────────────────────────────────────────────────
// DevelopmentSummary — bola rivojlanish ko'rsatkichi (#63), ota-ona ko'rinishi
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/children/:id/development-summary?range=weekly

import 'package:flutter/foundation.dart';

@immutable
class DevelopmentSummary {
  const DevelopmentSummary({
    required this.score,
    required this.trend,
    required this.xpGained,
    required this.testsCompleted,
    required this.booksRead,
    required this.streakDays,
    required this.steps,
  });

  factory DevelopmentSummary.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return DevelopmentSummary(
      score: i('score').clamp(0, 100),
      trend: i('trend'),
      xpGained: i('xpGained'),
      testsCompleted: i('testsCompleted'),
      booksRead: i('booksRead'),
      streakDays: i('streakDays'),
      steps: i('steps'),
    );
  }

  static const empty = DevelopmentSummary(
    score: 0,
    trend: 0,
    xpGained: 0,
    testsCompleted: 0,
    booksRead: 0,
    streakDays: 0,
    steps: 0,
  );

  final int score;
  final int trend;
  final int xpGained;
  final int testsCompleted;
  final int booksRead;
  final int streakDays;
  final int steps;

  bool get hasActivity =>
      xpGained > 0 ||
      testsCompleted > 0 ||
      booksRead > 0 ||
      steps > 0 ||
      streakDays > 0;
}
