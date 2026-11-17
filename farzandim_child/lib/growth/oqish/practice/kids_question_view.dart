// U05 · Savol (1–4-sinf): katta savol, 2 ustunli katta variantlar, javob shu
// ekranning o'zida tekshiriladi (alohida tushuntirish ekrani yo'q).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/oqish/practice/kids_practice_parts.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_parts.dart';
import 'package:flutter/material.dart';

class KidsQuestionView extends StatelessWidget {
  const KidsQuestionView({
    super.key,
    required this.subject,
    required this.session,
    required this.language,
    required this.onClose,
    required this.onSelect,
    required this.onCheck,
    required this.onNext,
    this.checkError,
  });

  final Subject subject;
  final QuizSession session;
  final String language;
  final String? checkError;
  final VoidCallback onClose;
  final ValueChanged<int> onSelect;
  final VoidCallback onCheck;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final question = s.current;
    final feedback = s.currentFeedback;
    final options = [for (final o in question.options) o.of(language)];
    final dock = feedback != null
        ? GButton(
            label: (s.isLast ? 'g5.practice.seeResult' : 'g5.practice.next')
                .tr(),
            size: GButtonSize.xl,
            trailingIcon: GIcons.arrowRight,
            onPressed: onNext,
          )
        : GButton(
            label: 'g5.practice.check'.tr(),
            size: GButtonSize.xl,
            loading: s.phase == QuizPhase.checking,
            onPressed: s.selectedIndex == null ? null : onCheck,
          );
    return GScreen(
      theme: GBgTheme.rose,
      top: PracticeTopBar(
        onClose: onClose,
        outcomes: s.outcomes,
        current: s.index + 1,
      ),
      dock: dock,
      children: [
        KidsQuestionCard(
          subject: subject,
          topic: question.topic.of(language),
          prompt: question.prompt.of(language),
          feedback: feedback == null
              ? null
              : KidsFeedback(
                  isCorrect: feedback.isCorrect,
                  correctAnswer: options[feedback.correctIndex],
                ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < options.length; i++)
                  SizedBox(
                    width: width,
                    child: KidsOption(
                      index: i,
                      text: options[i],
                      look: optionLookFor(i, s, feedback),
                      onTap: s.phase == QuizPhase.answering
                          ? () => onSelect(i)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
        if (checkError != null)
          GNote(
            text: checkError!,
            kind: GNoteKind.warn,
            icon: GIcons.wifiSlash,
          ),
      ],
    );
  }
}
