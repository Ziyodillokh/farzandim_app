// "So‘nggi natijalar" — o'rtacha natija halqasi, kuchli fan va tavsiya.
//
// Ma'lumot `learningSummaryProvider`dan (hozircha preview). Bosilsa
// Rivojlanish sahifasi ochiladi.

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RecentResultsCard extends ConsumerWidget {
  const RecentResultsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(learningSummaryProvider);
    if (!summary.hasResults) return const SizedBox.shrink();
    final strong = summary.strongSubject;
    final focus = summary.focusSubject;

    return GestureDetector(
      onTap: () => context.push('/progress'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: homeCardDecoration(),
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeSectionTitle(
              title: 'home.recentResults'.tr(),
              padding: const EdgeInsets.only(left: 6, right: 4),
            ),
            const SizedBox(height: 5),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _AverageTile(summary: summary)),
                  if (strong != null) ...[
                    const SizedBox(width: 7),
                    Expanded(
                      child: _InsightTile(
                        icon: const HomeSvgIcon(
                          homeBarsSvg,
                          size: 19,
                          color: HomeColors.green,
                        ),
                        caption: 'home.strongSubject'.tr(),
                        title: strong.labelKey.tr(),
                        footer: 'home.averagePercent'.tr(
                          namedArgs: {
                            'percent': '${summary.strongPercent ?? 0}',
                          },
                        ),
                      ),
                    ),
                  ],
                  if (focus != null) ...[
                    const SizedBox(width: 7),
                    Expanded(
                      child: _InsightTile(
                        icon: const HomeSvgIcon(
                          homeArrowUpRightSvg,
                          size: 19,
                          color: HomeColors.orange,
                        ),
                        caption: 'home.recommendation'.tr(),
                        title: focus.labelKey.tr(),
                        footer: 'home.workOnIt'.tr(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi + o'ng chevron (natijalar / kutubxona).
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
    this.titleSize = 18,
  });

  final String title;
  final EdgeInsets padding;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeDisplay(titleSize, letterSpacing: -0.3),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: HomeColors.chevron,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: padding ?? const EdgeInsets.fromLTRB(12, 13, 8, 9),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: child,
    );
  }
}

class _AverageTile extends StatelessWidget {
  const _AverageTile({required this.summary});

  final LearningSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProgressRing(percent: summary.averagePercent),
          const SizedBox(height: 2),
          Text(
            'home.averageResult'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeText(10.2, weight: FontWeight.w600, height: 1.2),
          ),
          const SizedBox(height: 1),
          Text(
            'home.lastTests'.plural(summary.recentTestCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeText(9.8, color: HomeColors.textDim, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.caption,
    required this.title,
    required this.footer,
  });

  final Widget icon;
  final String caption;
  final String title;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 7),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeText(9.8, color: HomeColors.textDim, height: 1.2),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeText(12.8, weight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 3),
          Text(
            footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeText(9.8, color: HomeColors.textDim, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// O'rtacha natija halqasi — tepadan soat yo'nalishida, yumaloq uchli.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(
        painter: _RingPainter(progress: percent.clamp(0, 100) / 100),
        child: Center(
          child: Text('$percent%', style: homeDisplay(12.7, height: 1)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;
  static const _stroke = 7.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = HomeColors.ringTrack;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = HomeColors.ring;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
