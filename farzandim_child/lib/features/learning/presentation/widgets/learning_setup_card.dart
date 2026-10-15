// Fan tanlanmagan bo'lsa "Bugungi testlar" o'rnida — sozlashga taklif.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class LearningSetupCard extends StatelessWidget {
  const LearningSetupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeColors.testsBorder),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [HomeColors.testsTop, HomeColors.testsBottom],
          stops: [0, 0.7],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HomeColors.calendarButton,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  SolarIconsBold.notebookBookmark,
                  size: 24,
                  color: HomeColors.subjectGlyph,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'learn.setupCtaTitle'.tr(),
                      style: homeDisplay(19, letterSpacing: -0.3, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'learn.setupCtaSubtitle'.tr(),
                      style: homeText(
                        13.5,
                        color: HomeColors.textDim,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: HomeColors.primary,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(LearningRoutes.setup),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: FitText(
                    'learn.setupCtaButton'.tr(),
                    style: homeText(14, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
