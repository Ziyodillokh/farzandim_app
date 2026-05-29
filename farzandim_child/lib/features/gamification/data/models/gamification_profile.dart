// ─────────────────────────────────────────────────────────────────────
// GamificationProfile — bola gamifikatsiya holati
// ─────────────────────────────────────────────────────────────────────
//
// Firestore: users/{parentUid}/children/{childId}/profile/gamification
// (alohida document — child fields'ni ifloslashidan saqlash).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';

class GamificationProfile {
  const GamificationProfile({
    required this.xp,
    required this.don,
    required this.streak,
    required this.lastActiveDate,
    required this.unlockedAchievements,
  });

  /// Jami XP — status va level shu raqamdan hisoblanadi.
  final int xp;

  /// DON valyuta balansi — konkurs bonus'lardan.
  final int don;

  /// Uzluksiz aktiv kunlar soni.
  final int streak;

  /// Eng oxirgi aktiv kun — streak hisoblash uchun.
  final DateTime? lastActiveDate;

  /// Unlock qilingan achievement ID'lari.
  final List<String> unlockedAchievements;

  /// Bo'sh boshlovchi profil (yangi bola uchun).
  factory GamificationProfile.empty() => const GamificationProfile(
        xp: 0,
        don: 0,
        streak: 0,
        lastActiveDate: null,
        unlockedAchievements: [],
      );

  // Hisoblangan qiymatlar
  GamificationStatus get status => statusForXp(xp);
  int get level => levelForXp(xp);

  /// Hozirgi status ichidagi progress (0.0 - 1.0).
  /// Mentor (xpCeiling=null) uchun har doim 1.0.
  double get progressToNextStatus {
    final floor = status.xpFloor;
    final ceiling = status.xpCeiling;
    if (ceiling == null) return 1.0;
    final delta = ceiling - floor;
    if (delta == 0) return 0.0;
    return ((xp - floor) / delta).clamp(0.0, 1.0);
  }

  /// Keyingi status'gacha qancha XP qoldi.
  int get xpToNextStatus {
    final ceiling = status.xpCeiling;
    if (ceiling == null) return 0; // Mentor — eng yuqori
    return (ceiling - xp).clamp(0, ceiling).toInt();
  }

  factory GamificationProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GamificationProfile(
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      don: (data['don'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastActiveDate:
          (data['lastActiveDate'] as Timestamp?)?.toDate(),
      unlockedAchievements:
          (data['unlockedAchievements'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'xp': xp,
        'don': don,
        'streak': streak,
        if (lastActiveDate != null)
          'lastActiveDate': Timestamp.fromDate(lastActiveDate!),
        'unlockedAchievements': unlockedAchievements,
      };

  GamificationProfile copyWith({
    int? xp,
    int? don,
    int? streak,
    DateTime? lastActiveDate,
    List<String>? unlockedAchievements,
  }) {
    return GamificationProfile(
      xp: xp ?? this.xp,
      don: don ?? this.don,
      streak: streak ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    );
  }
}
