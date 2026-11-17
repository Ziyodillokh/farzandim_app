// Savol kartasi — mavzu belgisi va savol matni (ko'k gradient fon).

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:flutter/material.dart';

class QuizQuestionCard extends StatelessWidget {
  const QuizQuestionCard({super.key, required this.topic, required this.text});

  final String topic;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: QuizColors.questionBorder),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [QuizColors.questionTop, QuizColors.questionBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topic.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: QuizColors.topicChip,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeText(
                  12.5,
                  weight: FontWeight.w600,
                  color: QuizColors.topicText,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(text, style: homeText(19, weight: FontWeight.w700, height: 1.4)),
        ],
      ),
    );
  }
}
