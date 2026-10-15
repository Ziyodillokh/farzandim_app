// "Haftalik rivojlanish" hero kartasi — umumiy o'sish, natija halqasi va
// 3 ko'rsatkich (testlar, to'g'ri javoblar, ketma-ket muvaffaqiyat).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/score_ring.dart';
import 'package:farzandim_child/features/progress/presentation/progress_icons.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

const _heroBase = Color(0xFF06172B);
const _heroTop = Color(0xFF0A2848);
const _ringGlow = Color(0x990C2F5C);
const _heroBorder = Color(0xFF113968);
const _divider = Color(0x14FFFFFF);
const _label = Color(0xFF94B1D6);
const _growthUp = Color(0xFF3DDFC6);
const _growthDown = Color(0xFFFF7A7A);
const _tileBg = Color(0xFF0E1D2D);
const _tileBorder = Color(0xFF10263D);
const _tileSquare = Color(0xFF112F57);
const _tileIcon = Color(0xFF86BBFF);

class ProgressHeroCard extends StatelessWidget {
  const ProgressHeroCard({super.key, required this.progress});

  final WeeklyProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _heroBase,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _heroBorder),
      ),
      child: Stack(
        children: [
          // Chap-yuqori burchakdagi yorug'lik va halqa atrofidagi ko'k nur.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-1.1, -1.2),
                  radius: 0.9,
                  colors: [_heroTop, Color(0x00092341)],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.72, -0.25),
                  radius: 0.75,
                  colors: [_ringGlow, Color(0x000C2F5C)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14.6, 9.5, 10.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: _Growth(progress: progress),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: SizedBox(
                        height: 66,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: _divider,
                        ),
                      ),
                    ),
                    const SizedBox(width: 29.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 0.5, right: 10),
                      child: _OverallRing(percent: progress.overallPercent),
                    ),
                  ],
                ),
                const SizedBox(height: 9.9),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(height: 1, thickness: 1, color: _divider),
                ),
                const SizedBox(height: 8.2),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: const Icon(
                          SolarIconsBold.fileText,
                          size: 19,
                          color: _tileIcon,
                        ),
                        value: '${progress.testsThisWeek}',
                        label: 'progress.testsThisWeek'.tr(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatTile(
                        icon: const HomeSvgIcon(
                          progressTargetSvg,
                          size: 20,
                          color: _tileIcon,
                        ),
                        value: '${progress.correctAnswers}',
                        label: 'progress.correctAnswers'.tr(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatTile(
                        icon: const HomeSvgIcon(
                          homeBarsSvg,
                          size: 17,
                          color: _tileIcon,
                        ),
                        value: '${progress.successStreak}',
                        label: 'progress.successStreak'.tr(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Growth extends StatelessWidget {
  const _Growth({required this.progress});

  final WeeklyProgress progress;

  @override
  Widget build(BuildContext context) {
    final up = progress.growthPercent >= 0;
    final color = up ? _growthUp : _growthDown;
    final sign = up ? '+' : '−';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'progress.weeklyLabel'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: homeText(
            12,
            weight: FontWeight.w400,
            color: _label,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 2.6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'progress.overallGrowth'.tr(),
            maxLines: 1,
            style: homeText(22, weight: FontWeight.w800, height: 1.25),
          ),
        ),
        const SizedBox(height: 8.2),
        Row(
          children: [
            SizedBox(
              width: 39,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Transform.flip(
                  flipY: !up,
                  child: HomeSvgIcon(progressTrendSvg, size: 25, color: color),
                ),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$sign${progress.growthPercent.abs()}%',
                  style: homeDisplay(22, color: color, letterSpacing: -0.3),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 39, top: 1.6),
          child: Text(
            'progress.vsLastWeek'.tr(),
            maxLines: 2,
            style: homeText(13, color: HomeColors.textDim, height: 1.25),
          ),
        ),
      ],
    );
  }
}

class _OverallRing extends StatelessWidget {
  const _OverallRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return ScoreRing(
      percent: percent,
      size: 112,
      // Matn bloki markazdan biroz pastda (maketdagidek).
      child: Padding(
        padding: const EdgeInsets.only(top: 8.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent%', style: homeDisplay(22.5, height: 1.1)),
              const SizedBox(height: 5),
              Text(
                'progress.overallResult'.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: homeText(12, color: HomeColors.textDim, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 4, 8),
      decoration: BoxDecoration(
        color: _tileBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tileSquare,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: icon,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: FitText(
                  value,
                  style: homeText(19, weight: FontWeight.w800, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Yorliq butun plitka kengligida — o'qiladigan o'lchamda; qatorlar
          // so'z o'rtasidan bo'linmaydi (tor joyda bir xil kichrayadi).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in label.split('\n'))
                  Text(
                    line,
                    maxLines: 1,
                    style: homeText(
                      12.5,
                      color: HomeColors.textDim,
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
