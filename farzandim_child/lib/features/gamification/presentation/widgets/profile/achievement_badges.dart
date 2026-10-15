// Profil — "Yutuqlar" kartasi (Growth uslubi): sarlavha + "ochilgan/jami",
// 3 ustunli nishonlar to'ri. Nishon bosilsa pastdan oyna (tabrik yoki shart).
//
// Manba o'zgarmagan: `Achievements.visible` katalogi + backend
// `unlockedAchievements` (ochilmaganlari qulflangan holda ko'rinadi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/achievement_medals.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/achievement_sheet.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

const _columns = 3;
const _gap = 10.0;

/// Nishon zonasi balandligi (medal / qulf shu ichida markazlanadi).
const _badgeArea = 64.0;
const _tilePaddingV = 12.0;
const _labelGap = 8.0;
const _labelSize = 11.5;
const _labelHeight = 1.25;
const _labelLines = 2;

class AchievementBadges extends StatelessWidget {
  const AchievementBadges({super.key, required this.unlockedIds});

  /// Backend'dagi ochilgan yutuqlar id'lari.
  final List<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
    final badges = [
      for (final a in Achievements.visible)
        AchievementBadgeSpec.from(a, unlocked: unlockedIds.contains(a.id)),
    ];
    final unlockedCount = badges.where((b) => b.unlocked).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: homeCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FitText(
                  'profile.achievements'.tr(),
                  style: homeText(19, weight: FontWeight.w800, height: 1.25),
                ),
              ),
              const SizedBox(width: 8),
              _Counter(text: '$unlockedCount/${badges.length}'),
            ],
          ),
          const SizedBox(height: 12),
          _BadgeGrid(badges: badges),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SolarIconsBold.medalRibbonStar,
            size: 14,
            color: HomeColors.amber,
          ),
          const SizedBox(width: 5),
          Text(text, style: homeText(13, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 3 ustunli to'r — qatorlar qo'lda (ichma-ich scroll yo'q). Katak balandligi
/// shrift masshtabiga qarab hisoblanadi: yorliq hech qachon kesilmaydi.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});

  final List<AchievementBadgeSpec> badges;

  @override
  Widget build(BuildContext context) {
    final label = MediaQuery.textScalerOf(context).scale(_labelSize);
    final extent =
        _tilePaddingV * 2 +
        _badgeArea +
        _labelGap +
        label * _labelHeight * _labelLines +
        4;
    return Column(
      children: [
        for (var start = 0; start < badges.length; start += _columns) ...[
          if (start > 0) const SizedBox(height: _gap),
          SizedBox(
            height: extent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + _columns; i++) ...[
                  if (i > start) const SizedBox(width: _gap),
                  Expanded(
                    child: i < badges.length
                        ? _BadgeTile(spec: badges[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.spec});

  final AchievementBadgeSpec spec;

  @override
  Widget build(BuildContext context) {
    final glow = spec.unlocked ? 0.24 : 0.08;
    return Semantics(
      button: true,
      label: spec.title,
      child: GestureDetector(
        onTap: () => showAchievementSheet(context, spec),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: _tilePaddingV,
            horizontal: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.tileBorder),
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 0.95,
              colors: [
                Color.alphaBlend(
                  spec.color.withValues(alpha: glow),
                  HomeColors.tile,
                ),
                HomeColors.tile,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: _badgeArea,
                child: Center(child: _medal()),
              ),
              const SizedBox(height: _labelGap),
              Text(
                spec.title,
                maxLines: _labelLines,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: homeText(
                  _labelSize,
                  weight: FontWeight.w600,
                  height: _labelHeight,
                  color: spec.unlocked ? HomeColors.text : HomeColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _medal() {
    if (!spec.unlocked) return LockMedal(color: spec.color);
    final asset = spec.asset;
    if (asset != null) {
      return Image.asset(asset, width: _badgeArea, height: _badgeArea);
    }
    return HexMedal(color: spec.color, icon: spec.icon);
  }
}
