// ─────────────────────────────────────────────────────────────────────
// XpEvent — XP yutuq event (Konsept v2 4.2)
// ─────────────────────────────────────────────────────────────────────
//
// Bola har bir XP yutgan harakatda log entry yoziladi. Tarix audit
// uchun + cheating detection (kelajak backend'da). Hozir Firestore'da.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Bola qaysi harakat uchun XP olgani.
enum XpEventType {
  bookCompleted,        // +50 XP
  contestJoined,        // +30 XP, +5 DON
  contestWon,           // +200 XP, +50 DON
  creativeContestJoined, // +25 XP, +5 DON
  courseLessonCompleted, // +20 XP
  dailyGoalCompleted,   // +10 XP
  weeklyStreak,         // +75 XP, +10 DON
  contentPublished,     // +25 XP (moderatsiyadan keyin)
}

extension XpEventTypeX on XpEventType {
  /// XP qiymati — Konsept v2 4.2 jadval'ga muvofiq.
  int get xpReward {
    switch (this) {
      case XpEventType.bookCompleted:
        return 50;
      case XpEventType.contestJoined:
        return 30;
      case XpEventType.contestWon:
        return 200;
      case XpEventType.creativeContestJoined:
        return 25;
      case XpEventType.courseLessonCompleted:
        return 20;
      case XpEventType.dailyGoalCompleted:
        return 10;
      case XpEventType.weeklyStreak:
        return 75;
      case XpEventType.contentPublished:
        return 25;
    }
  }

  /// DON valyuta qiymati — konkurs bonus'lar uchun.
  int get donReward {
    switch (this) {
      case XpEventType.contestJoined:
        return 5;
      case XpEventType.contestWon:
        return 50;
      case XpEventType.creativeContestJoined:
        return 5;
      case XpEventType.weeklyStreak:
        return 10;
      default:
        return 0;
    }
  }

  /// JSON lokalizatsiya kaliti — `gamification.xpEventXxx`.
  String get translationKey {
    switch (this) {
      case XpEventType.bookCompleted:
        return 'gamification.xpEventBookCompleted';
      case XpEventType.contestJoined:
        return 'gamification.xpEventContestJoined';
      case XpEventType.contestWon:
        return 'gamification.xpEventContestWon';
      case XpEventType.creativeContestJoined:
        return 'gamification.xpEventCreativeContestJoined';
      case XpEventType.courseLessonCompleted:
        return 'gamification.xpEventCourseLessonCompleted';
      case XpEventType.dailyGoalCompleted:
        return 'gamification.xpEventDailyGoalCompleted';
      case XpEventType.weeklyStreak:
        return 'gamification.xpEventWeeklyStreak';
      case XpEventType.contentPublished:
        return 'gamification.xpEventContentPublished';
    }
  }

  /// Firestore'da saqlash uchun string.
  String get firestoreCode {
    switch (this) {
      case XpEventType.bookCompleted:
        return 'book_completed';
      case XpEventType.contestJoined:
        return 'contest_joined';
      case XpEventType.contestWon:
        return 'contest_won';
      case XpEventType.creativeContestJoined:
        return 'creative_contest_joined';
      case XpEventType.courseLessonCompleted:
        return 'course_lesson_completed';
      case XpEventType.dailyGoalCompleted:
        return 'daily_goal_completed';
      case XpEventType.weeklyStreak:
        return 'weekly_streak';
      case XpEventType.contentPublished:
        return 'content_published';
    }
  }

  static XpEventType? fromCode(String code) {
    for (final v in XpEventType.values) {
      if (v.firestoreCode == code) return v;
    }
    return null;
  }
}

/// XP yutuq yozuvi (read-only — yaratilgach o'zgarmaydi).
class XpEvent {
  const XpEvent({
    required this.id,
    required this.type,
    required this.xpDelta,
    required this.donDelta,
    required this.createdAt,
    this.relatedId,
  });

  final String id;
  final XpEventType type;
  final int xpDelta;
  final int donDelta;
  final DateTime createdAt;

  /// Bog'liq entity ID — kitob/konkurs/kurs id. Audit + dedup uchun.
  final String? relatedId;

  factory XpEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final code = (data['type'] as String?) ?? '';
    return XpEvent(
      id: doc.id,
      type: XpEventTypeX.fromCode(code) ?? XpEventType.dailyGoalCompleted,
      xpDelta: (data['xpDelta'] as num?)?.toInt() ?? 0,
      donDelta: (data['donDelta'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      relatedId: data['relatedId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.firestoreCode,
        'xpDelta': xpDelta,
        'donDelta': donDelta,
        'createdAt': FieldValue.serverTimestamp(),
        if (relatedId != null) 'relatedId': relatedId,
      };
}
