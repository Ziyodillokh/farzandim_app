// Kelajak testi tepasi: yopish (✕), test nomi + "Savol 3/10" va javob
// berilganlar bo'yicha segmentli progress (javob berilgan — ko'k, joriy —
// och ko'k, qolgani — kulrang). To'g'ri / xato ranglari yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:flutter/material.dart';

class KelajakTopBar extends StatelessWidget {
  const KelajakTopBar({
    super.key,
    required this.title,
    required this.onClose,
    this.current,
    this.answered = const [],
  });

  final String title;
  final VoidCallback onClose;

  /// Joriy savol (0 dan) — `null` bo'lsa progress ko'rsatilmaydi.
  final int? current;

  /// Savol tartibida: javob berilganmi.
  final List<bool> answered;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final total = answered.length;
    final showProgress = current != null && total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HeaderIconButton(
              semanticLabel: 'common.close'.tr(),
              onTap: onClose,
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: homeText(16.5, weight: FontWeight.w700, height: 1.2),
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 2),
                    FitText(
                      'learn.questionOf'.tr(
                        namedArgs: {
                          'current': '${current + 1}',
                          'total': '$total',
                        },
                      ),
                      style: homeText(13, color: HomeColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (showProgress) ...[
          const SizedBox(height: 14),
          _Segments(current: current, answered: answered),
        ],
      ],
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.current, required this.answered});

  final int current;
  final List<bool> answered;

  @override
  Widget build(BuildContext context) {
    Color colorAt(int i) {
      if (answered[i]) return HomeColors.primary;
      if (i == current) return HomeColors.primary.withValues(alpha: 0.45);
      return QuizColors.segmentTrack;
    }

    // Ko'p savolda (20 ta) oraliq kichrayadi — segmentlar ko'rinib tursin.
    final gap = answered.length > 12 ? 3.0 : 4.0;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < answered.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: Container(
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
