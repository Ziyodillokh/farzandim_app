// ─────────────────────────────────────────────────────────────────────
// GamificationStatus — 5 ta status (Konsept v2 4.1)
// ─────────────────────────────────────────────────────────────────────
//
// Bola XP yig'ib status ko'taradi. Har status — Lv diapazoni + ochilgan
// imkoniyatlar. Lokalizatsiya: status nomi `gamification.status*` keylari.

import 'package:flutter/material.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';

enum GamificationStatus {
  beginner,    // Lv 1-3, 0-300 XP
  explorer,    // Lv 4-7, 300-900 XP
  knower,      // Lv 8-12, 900-2000 XP
  leader,      // Lv 13-20, 2000-5000 XP
  mentor,      // Lv 20+, 5000+ XP
}

extension GamificationStatusX on GamificationStatus {
  /// JSON kalit `gamification.status.<key>` uchun.
  String get translationKey {
    switch (this) {
      case GamificationStatus.beginner:
        return 'gamification.statusBeginner';
      case GamificationStatus.explorer:
        return 'gamification.statusExplorer';
      case GamificationStatus.knower:
        return 'gamification.statusKnower';
      case GamificationStatus.leader:
        return 'gamification.statusLeader';
      case GamificationStatus.mentor:
        return 'gamification.statusMentor';
    }
  }

  /// XP diapazoni boshi (status boshlanish chizigi).
  int get xpFloor {
    switch (this) {
      case GamificationStatus.beginner:
        return 0;
      case GamificationStatus.explorer:
        return 300;
      case GamificationStatus.knower:
        return 900;
      case GamificationStatus.leader:
        return 2000;
      case GamificationStatus.mentor:
        return 5000;
    }
  }

  /// XP diapazoni tepasi (`null` mentor uchun — cheksiz).
  int? get xpCeiling {
    switch (this) {
      case GamificationStatus.beginner:
        return 300;
      case GamificationStatus.explorer:
        return 900;
      case GamificationStatus.knower:
        return 2000;
      case GamificationStatus.leader:
        return 5000;
      case GamificationStatus.mentor:
        return null;
    }
  }

  /// Level diapazoni (display uchun, "Lv 1-3" kabi).
  String get levelRange {
    switch (this) {
      case GamificationStatus.beginner:
        return '1–3';
      case GamificationStatus.explorer:
        return '4–7';
      case GamificationStatus.knower:
        return '8–12';
      case GamificationStatus.leader:
        return '13–20';
      case GamificationStatus.mentor:
        return '20+';
    }
  }

  /// Rang accent — status badge uchun.
  Color get color {
    switch (this) {
      case GamificationStatus.beginner:
        return AppColors.catBlue; // sky blue
      case GamificationStatus.explorer:
        return AppColors.catViolet; // violet
      case GamificationStatus.knower:
        return AppColors.catEmeraldLight; // emerald
      case GamificationStatus.leader:
        return AppColors.catAmber; // amber
      case GamificationStatus.mentor:
        return AppColors.primary; // lime green
    }
  }

  /// Icon — status uchun visual identifier.
  IconData get icon {
    switch (this) {
      case GamificationStatus.beginner:
        return Icons.spa;
      case GamificationStatus.explorer:
        return Icons.explore;
      case GamificationStatus.knower:
        return Icons.menu_book;
      case GamificationStatus.leader:
        return Icons.workspace_premium;
      case GamificationStatus.mentor:
        return Icons.school;
    }
  }
}

/// XP miqdoriga qarab status hisoblash.
GamificationStatus statusForXp(int xp) {
  if (xp < 300) return GamificationStatus.beginner;
  if (xp < 900) return GamificationStatus.explorer;
  if (xp < 2000) return GamificationStatus.knower;
  if (xp < 5000) return GamificationStatus.leader;
  return GamificationStatus.mentor;
}

/// Level (1-30) hisoblash — XP'ni har 100'ga bo'lib + 1.
/// 0 XP → Lv 1; 100 → Lv 2; ... 2000 → Lv 21.
int levelForXp(int xp) => (xp ~/ 100) + 1;
