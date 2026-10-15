// Fan natijasi plitkasi — ikon, nom, foiz va progress chizig'i.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:flutter/material.dart';

const _tileBg = Color(0xFF0D1A27);
const _tileBorder = Color(0xFF13233A);
const _square = Color(0xFF1559C9);
const _track = Color(0xFF172B41);
const _fillStart = Color(0xFF1F78FA);
const _fillEnd = Color(0xFF5DBDFC);

class SubjectScoreTile extends StatelessWidget {
  const SubjectScoreTile({super.key, required this.score});

  final SubjectScore score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: _tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero'dagi stat plitkalari bilan bir xil: ikon + katta qiymat.
          Row(
            children: [
              SubjectIcon(
                subject: score.subject,
                size: 30,
                background: _square,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: FitText(
                  '${score.percent}%',
                  style: homeText(18, weight: FontWeight.w800, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fan nomi butun kenglikda — hamma plitkada bir xil o'lchamda.
          FitText(
            score.subject.labelKey.tr(),
            style: homeText(13, weight: FontWeight.w600, height: 1.2),
          ),
          const SizedBox(height: 10),
          ProgressLine(value: score.percent / 100),
        ],
      ),
    );
  }
}

/// Kuchli fanlar qatori — 3 ta teng plitka (3 tadan kam bo'lsa ham
/// plitkalar o'z kengligida qoladi).
class StrongSubjectsRow extends StatelessWidget {
  const StrongSubjectsRow({super.key, required this.scores});

  final List<SubjectScore> scores;

  static const _gap = 8.0;
  static const _slots = 3;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _slots; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(
            child: i < scores.length
                ? SubjectScoreTile(score: scores[i])
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

/// Yumaloq progress chizig'i (ko'k gradient).
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _track,
          borderRadius: BorderRadius.circular(height),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: const LinearGradient(colors: [_fillStart, _fillEnd]),
              boxShadow: [
                BoxShadow(
                  color: _fillEnd.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
