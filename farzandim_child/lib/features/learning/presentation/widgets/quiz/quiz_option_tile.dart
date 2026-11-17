// Javob varianti: harf doirasi (A–D) + matn. Holatlar: oddiy, tanlangan,
// tekshirilgandan keyin — to'g'ri (yashil), tanlangan xato (qizil),
// qolganlari xira.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:flutter/material.dart';

enum OptionState { idle, selected, correct, wrong, dimmed }

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

class QuizOptionTile extends StatelessWidget {
  const QuizOptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    this.onTap,
  });

  final int index;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border, letterBg, letterColor) = switch (state) {
      OptionState.idle || OptionState.dimmed => (
        QuizColors.option,
        QuizColors.optionBorder,
        QuizColors.letter,
        HomeColors.textDim,
      ),
      OptionState.selected => (
        QuizColors.selected.withValues(alpha: 0.16),
        QuizColors.selected,
        QuizColors.selected,
        Colors.white,
      ),
      OptionState.correct => (
        QuizColors.goodBg,
        QuizColors.good,
        QuizColors.good,
        const Color(0xFF05231E),
      ),
      OptionState.wrong => (
        QuizColors.badBg,
        QuizColors.bad,
        QuizColors.bad,
        const Color(0xFF2A0C0F),
      ),
    };
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';
    return Semantics(
      button: onTap != null,
      selected: state == OptionState.selected,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: state == OptionState.dimmed ? 0.5 : 1,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: border,
                width: state == OptionState.idle ? 1 : 1.6,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: letterBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: switch (state) {
                    OptionState.correct => Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: letterColor,
                    ),
                    OptionState.wrong => Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: letterColor,
                    ),
                    _ => Text(
                      letter,
                      style: homeText(
                        15,
                        weight: FontWeight.w700,
                        color: letterColor,
                        height: 1.1,
                      ),
                    ),
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: homeText(15.5, weight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
