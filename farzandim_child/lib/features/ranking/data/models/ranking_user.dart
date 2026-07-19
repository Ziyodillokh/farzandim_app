// ─────────────────────────────────────────────────────────────────────
// RankingUser — reyting tablo bandi
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class RankingUser {
  final String id;
  final String name;
  final int age;

  /// Jinsi ("male"/"female"/null) — reytingda jins+yoshga mos default
  /// avatarni ko'rsatish uchun (backend leaderboard qaytaradi).
  final String? gender;
  final String region;
  final int totalScore;
  final int weeklyScore;
  final int monthlyScore;
  final int dailyScore;
  final int streakDays;
  final int badgeCount;
  final int previousRank;
  final Color avatarColor;
  final bool isCurrentUser;

  const RankingUser({
    required this.id,
    required this.name,
    required this.age,
    required this.region,
    this.gender,
    required this.totalScore,
    required this.weeklyScore,
    required this.monthlyScore,
    required this.dailyScore,
    required this.streakDays,
    required this.badgeCount,
    required this.previousRank,
    required this.avatarColor,
    this.isCurrentUser = false,
  });

  String get yoshGuruhi {
    if (age <= 6) return '5-6';
    if (age <= 9) return '7-9';
    if (age <= 12) return '10-12';
    if (age <= 15) return '13-15';
    return '16-18';
  }
}
