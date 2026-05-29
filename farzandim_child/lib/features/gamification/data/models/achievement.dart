// ─────────────────────────────────────────────────────────────────────
// Achievement — yutuq nishonlari (Konsept v2 4.3)
// ─────────────────────────────────────────────────────────────────────
//
// Hozir 6 ta achievement — kelajakda kengaytirish. Unlock shartlari
// `XpService` ichida tekshiriladi (XP yutilganda check qilinadi).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.color,
    required this.checkUnlocked,
  });

  /// Unique ID — Firestore'da saqlanadi.
  final String id;

  /// Lokalizatsiya kalitlari.
  final String titleKey;
  final String descriptionKey;

  /// Vizual identifikator.
  final IconData icon;
  final Color color;

  /// Unlock shartini tekshiruvchi callback.
  /// `xp`, `bookCount`, `streak` kabi profil ma'lumotlari beriladi.
  final bool Function(AchievementCheckCtx) checkUnlocked;
}

class AchievementCheckCtx {
  const AchievementCheckCtx({
    required this.bookCount,
    required this.streak,
    required this.contestWins,
    required this.contestParticipations,
    required this.publishedContentCount,
    required this.helpfulAnswers,
  });

  final int bookCount;
  final int streak;
  final int contestWins;
  final int contestParticipations;
  final int publishedContentCount;
  final int helpfulAnswers;
}

/// 6 ta boshlang'ich achievement (Konsept v2 4.3).
class Achievements {
  Achievements._();

  static final List<Achievement> all = [
    Achievement(
      id: 'first_book',
      titleKey: 'gamification.achievementFirstBookTitle',
      descriptionKey: 'gamification.achievementFirstBookDesc',
      icon: Icons.menu_book,
      color: AppColors.catBlue,
      checkUnlocked: (ctx) => ctx.bookCount >= 1,
    ),
    Achievement(
      id: 'streak_10',
      titleKey: 'gamification.achievementStreak10Title',
      descriptionKey: 'gamification.achievementStreak10Desc',
      icon: AppIcons.streak,
      color: AppColors.catOrange,
      checkUnlocked: (ctx) => ctx.streak >= 10,
    ),
    Achievement(
      id: 'math_top10',
      titleKey: 'gamification.achievementMathTop10Title',
      descriptionKey: 'gamification.achievementMathTop10Desc',
      icon: Icons.calculate,
      color: AppColors.catViolet,
      checkUnlocked: (ctx) => false, // Reyting kelajak: TOP-10 trigger backend
    ),
    Achievement(
      id: 'contest_winner',
      titleKey: 'gamification.achievementContestWinnerTitle',
      descriptionKey: 'gamification.achievementContestWinnerDesc',
      icon: AppIcons.trophy,
      color: AppColors.catAmber,
      checkUnlocked: (ctx) => ctx.contestWins >= 1,
    ),
    Achievement(
      id: 'content_creator',
      titleKey: 'gamification.achievementContentCreatorTitle',
      descriptionKey: 'gamification.achievementContentCreatorDesc',
      icon: Icons.video_camera_back,
      color: AppColors.catPinkVibrant,
      checkUnlocked: (ctx) => ctx.publishedContentCount >= 5,
    ),
    Achievement(
      id: 'helper',
      titleKey: 'gamification.achievementHelperTitle',
      descriptionKey: 'gamification.achievementHelperDesc',
      icon: Icons.volunteer_activism,
      color: AppColors.catEmeraldLight,
      checkUnlocked: (ctx) => ctx.helpfulAnswers >= 1,
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
