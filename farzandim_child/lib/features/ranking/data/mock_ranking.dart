// ─────────────────────────────────────────────────────────────────────
// MockRanking — 50 ta foydalanuvchi (Дунё current user)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';

class MockRanking {
  MockRanking._();

  static const List<String> _names = [
    'Asilbek', 'Madina', 'Bekzod', 'Diyora', 'Sevinch', 'Jasur',
    'Malika', 'Akbar', 'Nilufar', 'Sardor', 'Gulnoza', 'Otabek',
    'Shahzoda', 'Farrux', 'Munisa', 'Davron', 'Aziza', 'Bobur',
    'Charos', 'Ulug\'bek', 'Dilfuza', 'Nodirbek', 'Hilola',
    'Fazliddin', 'Iroda', 'Komiljon', 'Kamola', 'Nurbek', 'Lola',
    'Sanjar', 'Mohira', 'Temur', 'Zarina', 'Eldor', 'Marjona',
    'Bekjon', 'Sevara', 'Murod', 'Manzura', 'Doniyor', 'Maftuna',
    'Ravshan', 'Saodat', 'Nurali', 'Zilola', 'Zafarbek', 'Nargiza',
    'Yorqin', 'Дунё', 'Ozodbek',
  ];

  static const List<String> _regions = [
    'Toshkent shahri',
    'Toshkent viloyati',
    'Andijon viloyati',
    'Buxoro viloyati',
    "Farg'ona viloyati",
    'Jizzax viloyati',
    'Xorazm viloyati',
    'Namangan viloyati',
    'Navoiy viloyati',
    'Qashqadaryo viloyati',
    'Samarqand viloyati',
    'Sirdaryo viloyati',
    'Surxondaryo viloyati',
    "Qoraqalpog'iston Respublikasi",
  ];

  static const List<Color> _colors = [
    AppColors.catPinkRose, AppColors.catLavenderDark, AppColors.catMint,
    AppColors.catOrangeWarm, AppColors.catLavender, AppColors.catPinkVibrant,
    AppColors.catGreen, AppColors.catOrangeLight, AppColors.catLimeBright,
    Color(0xFF9B59B6),
  ];

  static List<RankingUser> generateUsers() {
    return List<RankingUser>.generate(_names.length, (i) {
      final isCurrentUser = _names[i] == 'Дунё';
      final baseScore = (3000 - (i * 50) + (i * (i % 3))).clamp(100, 3500);

      return RankingUser(
        id: 'user_$i',
        name: _names[i],
        age: 5 + (i % 14),
        region: _regions[i % _regions.length],
        totalScore: baseScore,
        weeklyScore: (baseScore * 0.3).toInt(),
        monthlyScore: (baseScore * 0.7).toInt(),
        dailyScore: (baseScore * 0.05).toInt(),
        streakDays: i % 12,
        badgeCount: (i % 5) + 1,
        previousRank: i + (i % 5 == 0 ? 2 : -1),
        avatarColor: _colors[i % _colors.length],
        isCurrentUser: isCurrentUser,
      );
    });
  }
}
