// Yutuq oynasi (nishon bosilganda, pastdan) va yangi yutuq xabari.
// Ochilgan yutuq — tabrik, yopiq yutuq — ochish sharti.

import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/achievement_medals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';

const _sheetBg = Color(0xFF0C1622);

/// Nishon haqida oyna (haptic bilan).
Future<void> showAchievementSheet(
  BuildContext context,
  AchievementBadgeSpec spec,
) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _BadgeSheet(spec: spec),
  );
}

class _BadgeSheet extends StatelessWidget {
  const _BadgeSheet({required this.spec});

  final AchievementBadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 150, child: _SheetMedal(spec: spec)),
              const SizedBox(height: 8),
              Text(
                spec.title,
                textAlign: TextAlign.center,
                style: homeDisplay(20, letterSpacing: -0.2),
              ),
              const SizedBox(height: 8),
              Text(
                spec.desc,
                textAlign: TextAlign.center,
                style: homeText(13.5, color: HomeColors.textDim, height: 1.45),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HomeColors.primary,
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  spec.unlocked ? 'profile.accept'.tr() : 'common.ok'.tr(),
                  style: homeText(14.5, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oynadagi katta nishon + orqasida rangli nur.
class _SheetMedal extends StatelessWidget {
  const _SheetMedal({required this.spec});

  final AchievementBadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    final asset = spec.asset;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: spec.color.withValues(alpha: 0.42),
                blurRadius: 70,
                spreadRadius: 14,
              ),
            ],
          ),
        ),
        if (spec.unlocked && asset != null)
          Image.asset(asset, width: 132, height: 132)
        else if (spec.unlocked)
          SizedBox(
            width: 120,
            height: 120,
            child: FittedBox(
              child: HexMedal(color: spec.color, icon: spec.icon),
            ),
          )
        else ...[
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: ClipPath(
              clipper: HexClipper(),
              child: Container(
                width: 104,
                height: 114,
                color: spec.color.withValues(alpha: 0.8),
              ),
            ),
          ),
          const Icon(SolarIconsBold.lockKeyhole, color: Colors.white, size: 40),
        ],
      ],
    );
  }
}

/// Yangi yutuq ochilganda pastda chiqadigan xabar.
void showAchievementUnlockedToast(
  BuildContext context,
  Achievement achievement,
) {
  final tint = achievementTint(achievement);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tint.withValues(alpha: 0.45)),
      ),
      content: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(achievement.icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'gamification.achievementUnlockedTitle'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(13.5, weight: FontWeight.w700),
                ),
                Text(
                  achievement.titleKey.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(12.5, color: HomeColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
