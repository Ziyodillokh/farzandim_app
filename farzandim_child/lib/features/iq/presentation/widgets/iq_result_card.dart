// Natija kartasi (bola sahifasi va test oxiri). Holatga qarab:
// • NORMED — IQ raqami (100±15), 95% oraliq, daraja va persentil;
// • PROVISIONAL — "Taxminiy" belgisi, daraja va persentil, IQ raqamisiz.
// Har doim "Skrining, tashxis emas" izohi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:flutter/material.dart';

class IqResultCard extends StatelessWidget {
  const IqResultCard({super.key, required this.result});

  final IqResult result;

  @override
  Widget build(BuildContext context) {
    final color = iqBandColor(result.band);
    final score = result.standardScore;
    return Container(
      decoration: homeCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'iq.result.title'.tr(),
                  style: homeText(16, weight: FontWeight.w700),
                ),
              ),
              if (!result.isNormed) const _Chip(),
            ],
          ),
          const SizedBox(height: 14),
          if (result.isNormed && score != null) ...[
            Text(
              'IQ $score',
              style: homeText(34, weight: FontWeight.w800, color: color),
            ),
            if (result.ciLow != null && result.ciHigh != null)
              Text(
                'iq.result.range'.tr(
                  namedArgs: {
                    'low': '${result.ciLow}',
                    'high': '${result.ciHigh}',
                  },
                ),
                style: homeText(12.5, color: HomeColors.textDim),
              ),
            const SizedBox(height: 10),
          ],
          Text(
            iqBandLabel(result.band),
            style: homeText(
              result.isNormed ? 17 : 22,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'iq.result.percentile'.tr(namedArgs: {'p': '${result.percentile}'}),
            style: homeText(14, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'iq.result.correct'.tr(
              namedArgs: {
                'correct': '${result.correct}',
                'total': '${result.total}',
              },
            ),
            style: homeText(13, color: HomeColors.textDim),
          ),
          if (!result.isNormed) ...[
            const SizedBox(height: 10),
            Text(
              'iq.result.provisionalNote'.tr(),
              style: homeText(12, color: HomeColors.textDim, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'iq.disclaimer'.tr(),
            style: homeText(11.5, color: HomeColors.textDim, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomeColors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'iq.result.provisional'.tr(),
        style: homeText(11.5, weight: FontWeight.w700, color: HomeColors.amber),
      ),
    );
  }
}
