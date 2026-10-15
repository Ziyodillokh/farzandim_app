// Yutuq nishonlari — ma'lumot (katalogdan) va medal shakllari:
// olti burchakli medal (ochilgan) va qulf (yopiq). Profil to'ri va
// yutuq oynasi shu yerdan foydalanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ochilgan yutuq uchun tayyor medal PNG (katalog id → asset).
const _badgeAssets = <String, String>{
  'first_book': 'assets/icons/badge_book1.png',
  'math_top10': 'assets/icons/badge_top10.png',
};

/// Growth palitrasidagi nishon ranglari (katalogdagi binafsha emas).
const _badgeTints = <String, Color>{
  'first_book': HomeColors.blue,
  'streak_10': HomeColors.orange,
  'math_top10': HomeColors.green,
  'contest_winner': HomeColors.amber,
};

/// Yutuq rangi — Growth palitrasidan, bo'lmasa katalogdagi rang.
Color achievementTint(Achievement a) => _badgeTints[a.id] ?? a.color;

/// Nishon ko'rinishi uchun tayyor ma'lumot (tarjima qilingan).
class AchievementBadgeSpec {
  const AchievementBadgeSpec({
    required this.title,
    required this.desc,
    required this.color,
    required this.icon,
    required this.unlocked,
    this.asset,
  });

  factory AchievementBadgeSpec.from(Achievement a, {required bool unlocked}) =>
      AchievementBadgeSpec(
        title: a.titleKey.tr(),
        desc: a.descriptionKey.tr(),
        color: achievementTint(a),
        icon: a.icon,
        unlocked: unlocked,
        asset: _badgeAssets[a.id],
      );

  final String title;
  final String desc;
  final Color color;
  final IconData icon;
  final bool unlocked;

  /// Tayyor medal PNG (bo'lsa, geksagon chizilmaydi).
  final String? asset;
}

/// Olti burchakli medal — gradient + ichki kontur + ikon.
/// Tayyor PNG bo'lmagan yutuqlar uchun.
class HexMedal extends StatelessWidget {
  const HexMedal({super.key, required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.35)!;
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          ClipPath(
            clipper: HexClipper(),
            child: Container(
              width: 54,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [light, color, dark],
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: HexClipper(),
            child: Container(
              width: 44,
              height: 47,
              color: Color.lerp(color, Colors.black, 0.18),
            ),
          ),
          Icon(icon, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}

/// Yopiq yutuq — xira rangli yumaloq kvadrat ichida qulf.
class LockMedal extends StatelessWidget {
  const LockMedal({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.16), HomeColors.tile),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 18),
        ],
      ),
      child: Icon(SolarIconsBold.lockKeyhole, color: color, size: 22),
    );
  }
}

/// Uchi tepada bo'lgan (pointy-top) olti burchak.
class HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w / 2, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
