// Psixologik test savoli: savol kartasi (turi bilan), javoblar va pastda
// "Keyingi" / "Yakunlash". Tugma javob tanlanmaguncha yopiq; MULTI'da bo'sh
// tanlov ham javob ("hech biri mos emas").

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_question_card.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/psych_session.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:farzandim_child/features/school/presentation/widgets/psych/psych_choice_tile.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';

class PsychQuestionView extends StatelessWidget {
  const PsychQuestionView({
    super.key,
    required this.session,
    required this.onChoose,
    required this.onRate,
    required this.onNext,
  });

  final PsychSession session;

  /// SINGLE / MULTI varianti bosildi (kalit).
  final ValueChanged<String> onChoose;

  /// LIKERT bahosi tanlandi (1..5).
  final ValueChanged<int> onRate;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final item = session.current;
    return Column(
      children: [
        Expanded(
          child: ListView(
            // Har savol yuqoridan boshlanadi.
            key: ValueKey('psych-item-${item.id}'),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            children: [
              QuizQuestionCard(
                topic: psychKindLabelKey(session.test.kind).tr(),
                text: item.text,
              ),
              const SizedBox(height: 14),
              ..._choices(item, session.currentAnswer),
            ],
          ),
        ),
        SchoolBottomBar(
          children: [
            SetupButton(
              label:
                  (session.isLast ? 'school.psych.finish' : 'school.psych.next')
                      .tr(),
              onTap: session.canAdvance ? onNext : null,
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _choices(PsychItem item, PsychAnswer? answer) {
    final tiles = switch (item) {
      PsychLikertItem() => [
        for (final value in likertValues)
          PsychChoiceTile(
            marker: PsychMarker.number,
            number: value,
            text: likertLabelKey(value).tr(),
            selected: answer is PsychLikertAnswer && answer.value == value,
            onTap: () => onRate(value),
          ),
      ],
      PsychSingleItem(:final options) => [
        for (final option in options)
          PsychChoiceTile(
            marker: PsychMarker.radio,
            text: option.text,
            selected: answer is PsychSingleAnswer && answer.key == option.key,
            onTap: () => onChoose(option.key),
          ),
      ],
      PsychMultiItem(:final options) => [
        for (final option in options)
          PsychChoiceTile(
            marker: PsychMarker.checkbox,
            text: option.text,
            selected:
                answer is PsychMultiAnswer && answer.keys.contains(option.key),
            onTap: () => onChoose(option.key),
          ),
      ],
    };
    return [
      if (item is PsychMultiItem) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'school.psych.multiHint'.tr(),
            style: homeText(13, color: HomeColors.textDim, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
      ],
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        tiles[i],
      ],
    ];
  }
}
