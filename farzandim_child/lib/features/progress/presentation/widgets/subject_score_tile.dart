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

  /// Shundan tor plitka — ixcham (kichikroq ikon va oraliqlar).
  static const _compactBelow = 90.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => _build(c.maxWidth < _compactBelow),
    );
  }

  Widget _build(bool compact) {
    final side = compact ? 8.0 : 10.0;
    return Container(
      padding: EdgeInsets.fromLTRB(side, 10.5, side, 12.4),
      decoration: BoxDecoration(
        color: _tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SubjectIcon(
                subject: score.subject,
                size: compact ? 24 : 30,
                background: _square,
              ),
              SizedBox(width: compact ? 7 : 9.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uzun nom (ru/en) kesilmay, sig'guncha kichrayadi.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        score.subject.labelKey.tr(),
                        maxLines: 1,
                        style: homeText(
                          12,
                          weight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${score.percent}%',
                        maxLines: 1,
                        style: homeText(
                          14,
                          weight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11.5),
          ProgressLine(value: score.percent / 100),
        ],
      ),
    );
  }
}

/// Kuchli fanlar qatori — plitka kengligi fan nomi uzunligiga mos
/// (maketdagidek: "Matematika" kengroq, "Ona tili" torroq), umumiy
/// kenglikni to'ldiradi.
class StrongSubjectsRow extends StatelessWidget {
  const StrongSubjectsRow({super.key, required this.scores});

  final List<SubjectScore> scores;

  static const _gap = 7.8;

  /// Matndan tashqari kenglik: chap 10 + ikon 30 + oraliq 9.5 + o'ng 10 + 2.
  static const _chrome = 61.5;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Shrift (google_fonts) yuklanib bo'lgach matn o'lchovlari qayta
    // hisoblansin — aks holda kengliklar zaxira shriftda qolib ketadi.
    listenable: PaintingBinding.instance.systemFonts,
    builder: (context, _) => _layout(context),
  );

  Widget _layout(BuildContext context) {
    final style = homeText(12, weight: FontWeight.w600, height: 1.2);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text) => (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout()).width;
    // 3 tadan kam fan bo'lsa ham plitkalar maketdagi kenglikda qoladi.
    final natural = [
      for (final s in scores) _chrome + measure(s.subject.labelKey.tr()),
      for (var i = scores.length; i < 3; i++) 110.0,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final available = c.maxWidth - _gap * (natural.length - 1);
        final widths = fitTileWidths(natural, available);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < natural.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              SizedBox(
                width: widths[i],
                child: i < scores.length
                    ? SubjectScoreTile(score: scores[i])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tabiiy (matnga mos) kengliklar — maketdagidek. Tor ekranda biror plitka
/// [_minProportional] dan torayib qolsa — teng kengliklar.
const _minProportional = 95.0;

@visibleForTesting
List<double> fitTileWidths(List<double> natural, double available) {
  final total = natural.fold<double>(0, (a, b) => a + b);
  final proportional = [for (final w in natural) w * available / total];
  if (proportional.every((w) => w >= _minProportional)) return proportional;
  return List.filled(natural.length, available / natural.length);
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
