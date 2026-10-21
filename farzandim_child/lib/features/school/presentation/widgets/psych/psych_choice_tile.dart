// Psixologik test javobi — kunlik test varianti uslubida. Chap belgi savol
// turiga qarab: LIKERT — raqam (1..5), SINGLE — doira, MULTI — kvadrat
// (bir nechta tanlanadi). Tanlangani ko'k chegarali.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:flutter/material.dart';

/// Javob belgisi turi.
enum PsychMarker {
  /// Raqam (LIKERT bahosi).
  number,

  /// Doira — bitta variant.
  radio,

  /// Kvadrat — bir nechta variant.
  checkbox,
}

class PsychChoiceTile extends StatelessWidget {
  const PsychChoiceTile({
    super.key,
    required this.marker,
    required this.text,
    required this.selected,
    required this.onTap,
    this.number,
  });

  final PsychMarker marker;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  /// [PsychMarker.number] uchun raqam.
  final int? number;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: marker != PsychMarker.checkbox,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          decoration: BoxDecoration(
            color: selected
                ? QuizColors.selected.withValues(alpha: 0.16)
                : QuizColors.option,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? QuizColors.selected : QuizColors.optionBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              _Marker(marker: marker, selected: selected, number: number),
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
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.marker,
    required this.selected,
    required this.number,
  });

  final PsychMarker marker;
  final bool selected;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? QuizColors.selected : QuizColors.letter;
    if (marker == PsychMarker.number) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          '${number ?? ''}',
          style: homeText(
            15,
            weight: FontWeight.w700,
            color: selected ? Colors.white : HomeColors.textDim,
            height: 1.1,
          ),
        ),
      );
    }
    final isRadio = marker == PsychMarker.radio;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? QuizColors.selected : Colors.transparent,
        shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isRadio ? null : BorderRadius.circular(8),
        border: Border.all(
          color: selected ? QuizColors.selected : HomeColors.textDim,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : null,
    );
  }
}
