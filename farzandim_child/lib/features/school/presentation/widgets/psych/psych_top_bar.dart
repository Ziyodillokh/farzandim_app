// Psixologik test tepasi: yopish (✕), test nomi + "Savol 3/12", qolgan vaqt
// (chegara bo'lsa) va uzluksiz progress chizig'i.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Shu qolganda vaqt belgisi sariq bo'ladi.
const _warnBelow = Duration(minutes: 1);

class PsychTopBar extends StatelessWidget {
  const PsychTopBar({
    super.key,
    required this.title,
    required this.onClose,
    this.current,
    this.total,
    this.progress,
    this.remaining,
  });

  final String title;
  final VoidCallback onClose;

  /// Joriy savol (1 dan) va jami — `null` bo'lsa ko'rsatilmaydi.
  final int? current;
  final int? total;

  /// 0..1 — `null` bo'lsa chiziq yo'q (kirish bosqichi).
  final double? progress;

  /// Qolgan vaqt — `null`: cheklanmagan.
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final total = this.total;
    final progress = this.progress;
    final remaining = this.remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HeaderIconButton(
              semanticLabel: 'common.close'.tr(),
              onTap: onClose,
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: homeText(16.5, weight: FontWeight.w700, height: 1.2),
                  ),
                  if (current != null && total != null) ...[
                    const SizedBox(height: 2),
                    FitText(
                      'learn.questionOf'.tr(
                        namedArgs: {'current': '$current', 'total': '$total'},
                      ),
                      style: homeText(13, color: HomeColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
            if (remaining != null) ...[
              const SizedBox(width: 10),
              _TimeLeft(remaining: remaining),
            ],
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 14),
          _ProgressLine(value: progress),
        ],
      ],
    );
  }
}

class _TimeLeft extends StatelessWidget {
  const _TimeLeft({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final text = formatCountdown(remaining);
    final color = remaining <= _warnBelow ? HomeColors.amber : HomeColors.text;
    return Semantics(
      label: 'school.psych.timeLeft'.tr(namedArgs: {'time': text}),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
        decoration: BoxDecoration(
          color: HomeColors.tile,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: remaining <= _warnBelow
                ? HomeColors.amber.withValues(alpha: 0.5)
                : HomeColors.tileBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(SolarIconsOutline.stopwatch, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: homeText(
                14,
                weight: FontWeight.w700,
                color: color,
                height: 1.2,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: QuizColors.segmentTrack),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [HomeColors.blue, HomeColors.primary],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
