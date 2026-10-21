// Kelajak savoli: tekis karta (mavzu, "Ixtiyoriy" belgisi va savol matni)
// va javob — variantlar (har bir yorliq to'liq, harfsiz, to'g'ri / xato
// ranglarisiz) yoki ochiq matn maydoni. Har savol yuqoridan boshlanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/session/kelajak_text_answer.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_choice_tile.dart';
import 'package:flutter/material.dart';

class KelajakQuestionView extends StatelessWidget {
  const KelajakQuestionView({
    super.key,
    required this.question,
    required this.answer,
    required this.isOptional,
    required this.enabled,
    required this.onSelect,
    this.textController,
  });

  final KelajakQuestion question;
  final KelajakAnswer? answer;

  /// Javobsiz o'tish mumkin (`career_lab_5`, ochiq matn).
  final bool isOptional;

  /// Javob tanlash / yozish mumkin (sessiya ochiq, yakunlanmayapti).
  final bool enabled;
  final ValueChanged<int> onSelect;

  /// Ochiq savol uchun (boshqa turda `null`).
  final TextEditingController? textController;

  @override
  Widget build(BuildContext context) {
    final controller = textController;
    return ListView(
      key: ValueKey('kelajak-question-${question.id}'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      children: [
        _QuestionCard(
          category: question.categoryName?.inLocale(context),
          text: question.text.inLocale(context),
          isOptional: isOptional,
        ),
        const SizedBox(height: 14),
        if (question.isText && controller != null)
          KelajakTextAnswer(
            controller: controller,
            maxLength: question.textLimit,
            enabled: enabled,
          )
        else
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _option(context, question.options[i]),
          ],
      ],
    );
  }

  Widget _option(BuildContext context, KelajakOption option) {
    return PsychChoiceTile(
      marker: PsychMarker.radio,
      text: option.label.inLocale(context),
      selected: answer?.value == option.value,
      onTap: () {
        if (enabled) onSelect(option.value);
      },
    );
  }
}

/// Tekis savol kartasi (gradientsiz).
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.category,
    required this.text,
    required this.isOptional,
  });

  final String? category;
  final String text;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final category = this.category?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: homeCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty || isOptional) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (category.isNotEmpty)
                  _Tag(category, color: QuizColors.topicText),
                if (isOptional)
                  _Tag(
                    'kelajak.session.optional'.tr(),
                    color: HomeColors.textDim,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(text, style: homeText(19, weight: FontWeight.w700, height: 1.4)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: homeText(12.5, weight: FontWeight.w600, color: color),
      ),
    );
  }
}
