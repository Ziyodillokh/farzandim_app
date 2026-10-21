// Stimul — savoldan oldin bir necha soniya eslab qolinadigan matn
// (xotira / diqqat testlari): "Eslab qoling!", matn, qolgan soniyalar va
// "Savolga o'tish". Vaqt tugasa savol o'zi ochiladi; stimul qayta
// ko'rsatilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class PsychStimulusView extends StatelessWidget {
  const PsychStimulusView({
    super.key,
    required this.text,
    required this.secondsLeft,
    required this.onSkip,
  });

  final String text;
  final int secondsLeft;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  SolarIconsOutline.eye,
                  size: 20,
                  color: HomeColors.blue,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'school.psych.remember'.tr(),
                    textAlign: TextAlign.center,
                    style: homeText(
                      15,
                      weight: FontWeight.w800,
                      color: HomeColors.blue,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
              decoration: BoxDecoration(
                color: HomeColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: HomeColors.blue.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: homeDisplay(24, weight: FontWeight.w700, height: 1.4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'school.psych.seconds'.tr(namedArgs: {'sec': '$secondsLeft'}),
              textAlign: TextAlign.center,
              style: homeDisplay(
                28,
                color: HomeColors.textDim,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: onSkip,
                child: Text(
                  'school.psych.toQuestion'.tr(),
                  style: homeText(
                    14.5,
                    weight: FontWeight.w600,
                    color: HomeColors.textDim,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
