// Javob tekshirilgach: "To'g'ri!" / "Noto'g'ri" + (xato bo'lsa) to'g'ri
// javob va izoh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class QuizFeedbackCard extends StatelessWidget {
  const QuizFeedbackCard({
    super.key,
    required this.isCorrect,
    required this.explanation,
    this.correctAnswer,
  });

  final bool isCorrect;
  final String explanation;

  /// Xato javobda ko'rsatiladigan to'g'ri variant matni.
  final String? correctAnswer;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? QuizColors.good : QuizColors.bad;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: isCorrect ? QuizColors.goodBg : QuizColors.badBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCorrect ? QuizColors.goodBorder : QuizColors.badBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? SolarIconsBold.checkCircle
                    : SolarIconsBold.dangerCircle,
                size: 22,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (isCorrect ? 'learn.correct' : 'learn.wrong').tr(),
                  style: homeText(16, weight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          if (correctAnswer != null) ...[
            const SizedBox(height: 8),
            Text(
              'learn.correctAnswer'.tr(namedArgs: {'answer': correctAnswer!}),
              style: homeText(14, weight: FontWeight.w700, height: 1.35),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            explanation,
            style: homeText(14, color: HomeColors.textDim, height: 1.45),
          ),
        ],
      ),
    );
  }
}
