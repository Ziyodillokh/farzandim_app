// Test sahifasi tepasi: yopish (✕), fan nomi + "Savol 3/10" va
// segmentli progress (to'g'ri — yashil, xato — qizil, joriy — ko'k).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:flutter/material.dart';

class QuizTopBar extends StatelessWidget {
  const QuizTopBar({
    super.key,
    required this.subject,
    required this.onClose,
    this.current,
    this.total,
    this.outcomes = const [],
  });

  final Subject subject;
  final VoidCallback onClose;

  /// Joriy savol (1 dan) va jami — `null` bo'lsa progress ko'rsatilmaydi.
  final int? current;
  final int? total;

  /// Savol tartibida natija: to'g'ri / xato / `null` (javobsiz).
  final List<bool?> outcomes;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final total = this.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HeaderIconButton(
              semanticLabel: 'learn.close'.tr(),
              onTap: onClose,
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            SubjectIcon(subject: subject, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FitText(
                    subject.labelKey.tr(),
                    style: homeText(16.5, weight: FontWeight.w700, height: 1.2),
                  ),
                  if (current != null && total != null) ...[
                    const SizedBox(height: 2),
                    FitText(
                      'learn.questionOf'.tr(
                        namedArgs: {'current': '$current', 'total': '$total'},
                      ),
                      style: homeText(13, color: HomeColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (current != null && total != null) ...[
          const SizedBox(height: 16),
          _Segments(current: current, total: total, outcomes: outcomes),
        ],
      ],
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.current,
    required this.total,
    required this.outcomes,
  });

  final int current;
  final int total;
  final List<bool?> outcomes;

  @override
  Widget build(BuildContext context) {
    Color colorAt(int i) {
      final outcome = i < outcomes.length ? outcomes[i] : null;
      if (outcome != null) return outcome ? QuizColors.good : QuizColors.bad;
      if (i == current - 1) return QuizColors.selected;
      return QuizColors.segmentTrack;
    }

    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  color: colorAt(i),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
