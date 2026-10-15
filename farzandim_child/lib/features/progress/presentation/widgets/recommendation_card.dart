// "Tavsiya" kartasi — eng past natijali fandan test ishlash taklifi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/progress/presentation/progress_icons.dart';
import 'package:farzandim_child/features/tests/presentation/open_subject_tests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

const _cardTop = Color(0xFF07182B);
const _cardBottom = Color(0xFF051120);
const _cardBorder = Color(0xFF0B2747);
const _square = Color(0xFF131C27);
const _bulb = Color(0xFFFFC93C);
const _buttonStart = Color(0xFF1A72F7);
const _buttonEnd = Color(0xFF3F8BFA);
const _buttonBorder = Color(0xFF5A9DFF);

/// Belgi — tarjimadagi `{subject}` o'rnini qalin fan nomi bilan almashtirish.
const _subjectMark = '\u0000';

class RecommendationCard extends ConsumerWidget {
  const RecommendationCard({super.key, required this.recommendation});

  final ProgressRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = recommendation.subject.labelKey.tr();
    final template = 'progress.recommendationText'.tr(
      namedArgs: {
        'subject': _subjectMark,
        'count': '${recommendation.testCount}',
      },
    );
    final parts = template.split(_subjectMark);
    final dim = homeText(13, color: HomeColors.textDim, height: 1.45);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10.5, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cardTop, _cardBottom],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _square,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HomeColors.cardBorder),
            ),
            child: const HomeSvgIcon(progressBulbSvg, size: 27, color: _bulb),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'progress.recommendation'.tr(),
                  style: homeText(19.5, weight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: dim,
                    children: [
                      for (var i = 0; i < parts.length; i++) ...[
                        if (i > 0)
                          TextSpan(
                            text: subject,
                            // copyWith(fontWeight) bundle'dagi SemiBold faylni
                            // yuklamaydi — alohida stil kerak.
                            style: homeText(
                              13,
                              weight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.45,
                            ),
                          ),
                        TextSpan(text: parts[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _DoTestButton(
              onTap: () =>
                  openSubjectTests(context, ref, [recommendation.subject]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoTestButton extends StatelessWidget {
  const _DoTestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Ko'rinishi 36pt (maket), bosish maydoni 44pt.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _visual(),
      ),
    );
  }

  Widget _visual() {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(side: BorderSide(color: _buttonBorder)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_buttonStart, _buttonEnd]),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.5),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'progress.doTest'.tr(),
                    style: homeText(14, weight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    SolarIconsOutline.arrowRight,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
