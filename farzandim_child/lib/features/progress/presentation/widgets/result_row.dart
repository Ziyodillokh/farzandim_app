// So'nggi natija qatori — fan ikoni, mavzu, ball "pill"i, sana, chevron.
// Bosilsa javoblar tahlili.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:flutter/material.dart';

const _rowBg = Color(0xFF0D1A27);
const _rowBorder = Color(0x0FFFFFFF);
const _square = Color(0xFF1559C9);

/// Ball darajasi ranglari: (matn, chegara, fon).
(Color, Color, Color) scoreColors(ScoreLevel level) => switch (level) {
  ScoreLevel.good => (
    const Color(0xFF45E2BE),
    const Color(0xFF1F6E62),
    const Color(0xFF0B272D),
  ),
  ScoreLevel.medium => (
    const Color(0xFFFFC13F),
    const Color(0xFF6F5732),
    const Color(0xFF1E2222),
  ),
  ScoreLevel.low => (
    const Color(0xFFFF7C7C),
    const Color(0xFF6E2F35),
    const Color(0xFF261A20),
  ),
};

/// "12 fev" — joriy yilda yilsiz; boshqa yil uchun "12 fev, 2024".
String formatResultDate(DateTime d, {DateTime? now}) {
  final month = monthNameFrom('common.monthsShort'.tr(), d.month);
  final sameYear = d.year == (now ?? DateTime.now()).year;
  return sameYear ? '${d.day} $month' : '${d.day} $month, ${d.year}';
}

/// Fan + mavzu: "Matematika. Arifmetika" (mavzu bo'lmasa — faqat fan).
String resultTitle(BuildContext context, TestResult r) {
  final subject = r.subject.labelKey.tr();
  final topic = r.topic.of(context.locale.languageCode).trim();
  return topic.isEmpty ? subject : '$subject. $topic';
}

class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.result});

  final TestResult result;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => openResultReview(context, result),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.fromLTRB(6.5, 4.5, 6, 4.5),
          decoration: BoxDecoration(
            color: _rowBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _rowBorder),
          ),
          child: Row(
            children: [
              SubjectIcon(
                subject: result.subject,
                size: 36,
                background: _square,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      resultTitle(context, result),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: homeText(
                        13.5,
                        weight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'home.questions'.plural(result.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: homeText(
                        12,
                        color: HomeColors.textDim,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ScorePill(result: result),
              const SizedBox(width: 14),
              SizedBox(
                // Shrift masshtabi bilan kengayadi (sana kesilmasin).
                width: MediaQuery.textScalerOf(context).scale(52),
                child: Text(
                  formatResultDate(result.date),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: homeText(12, color: HomeColors.textDim),
                ),
              ),
              const SizedBox(width: 13),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: HomeColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "9/10" — daraja rangida chegarali pill.
class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.result, this.fontSize = 14.5});

  final TestResult result;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (text, border, bg) = scoreColors(result.level);
    return Container(
      constraints: const BoxConstraints(minWidth: 47, minHeight: 25.8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Text(
        '${result.correct}/${result.total}',
        style: homeText(
          fontSize,
          weight: FontWeight.w600,
          color: text,
          height: 1.1,
        ),
      ),
    );
  }
}
