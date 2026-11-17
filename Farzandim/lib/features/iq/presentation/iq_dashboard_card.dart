// IqDashboardCard — dashboard'dagi IQ test natijasi (Kelajak kartasidan keyin).
//
// Ota-ona to'liq natijani ko'radi (docs/IQ-REJA.md): daraja (yumshoq matn,
// LOW/VERY_LOW — "Rivojlanish zonasi"), persentil, norma yetarli bo'lmasa
// "Taxminiy" belgisi; standart ball + 95% oraliq faqat NORMED holatda;
// har doim "Skrining, tashxis emas". Natija yo'q / bo'lim yo'q — ko'rinmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/features/iq/data/iq_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _cardBg = Color(0x12FFFFFF);
const Color _cardBorder = Color(0x1AFFFFFF);
const Color _dim = Color(0x8CFFFFFF);
const Color _chip = Color(0xFFFFC56B);

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.5,
  height: 1.4,
);

TextStyle _pop(double size, {Color color = _dim, FontWeight? w}) =>
    GoogleFonts.poppins(
      fontSize: size,
      color: color,
      fontWeight: w,
      height: 1.5,
    );

/// Dashboard pull-to-refresh.
void refreshIqCard(WidgetRef ref, String childId) =>
    ref.invalidate(iqSummaryProvider(childId));

/// Daraja kodi → tarjima kaliti (LOW va VERY_LOW — bitta yumshoq matn).
String iqBandKey(String band) => switch (band) {
  'LOW' || 'VERY_LOW' => 'iq.band.growthZone',
  'VERY_HIGH' => 'iq.band.veryHigh',
  'HIGH' => 'iq.band.high',
  'ABOVE_AVERAGE' => 'iq.band.aboveAverage',
  'BELOW_AVERAGE' => 'iq.band.belowAverage',
  _ => 'iq.band.average',
};

String _day(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.${d.year}';

class IqDashboardCard extends ConsumerWidget {
  const IqDashboardCard({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(appLifecycleProvider, (previous, next) {
      if (next == AppLifecycleState.resumed && previous != next) {
        refreshIqCard(ref, childId);
      }
    });
    final summary = ref.watch(iqSummaryProvider(childId)).valueOrNull;
    final last = summary?.last;
    if (summary == null || last == null) return const SizedBox.shrink();
    final next = summary.nextAvailableAt;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 26, color: _dim),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'iq.card.title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(16),
                    ),
                  ),
                  if (!last.isNormed) const _ProvisionalChip(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                iqBandKey(last.band).tr(),
                style: _pop(16, color: Colors.white, w: FontWeight.w600),
              ),
              if (last.percentile != null)
                Text(
                  'iq.card.percentile'.tr(
                    namedArgs: {'p': '${last.percentile}'},
                  ),
                  style: _pop(14, color: Colors.white),
                ),
              if (last.isNormed && last.standardScore != null)
                Text(
                  last.ci95 == null
                      ? 'iq.card.score'.tr(
                          namedArgs: {'score': '${last.standardScore}'},
                        )
                      : 'iq.card.scoreCi'.tr(
                          namedArgs: {
                            'score': '${last.standardScore}',
                            'lo': '${last.ci95!.$1}',
                            'hi': '${last.ci95!.$2}',
                          },
                        ),
                  style: _pop(14, color: Colors.white),
                ),
              Text(
                'iq.card.correct'.tr(
                  namedArgs: {
                    'correct': '${last.correct}',
                    'total': '${last.total}',
                    'date': _day(last.completedAt),
                  },
                ),
                style: _pop(13),
              ),
              if (last.domains.isNotEmpty)
                Text(
                  [
                    for (final d in last.domains)
                      '${'iq.kind.${d.kind}'.tr()} ${d.right}/${d.total}',
                  ].join(' · '),
                  style: _pop(13),
                ),
              if (summary.previous?.percentile != null)
                Text(
                  'iq.card.previous'.tr(
                    namedArgs: {
                      'p': '${summary.previous!.percentile}',
                      'date': _day(summary.previous!.completedAt),
                    },
                  ),
                  style: _pop(13),
                ),
              if (next != null && next.isAfter(DateTime.now()))
                Text(
                  'iq.card.retake'.tr(namedArgs: {'date': _day(next)}),
                  style: _pop(13),
                ),
              const SizedBox(height: 6),
              Text('iq.card.disclaimer'.tr(), style: _pop(12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvisionalChip extends StatelessWidget {
  const _ProvisionalChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: _chip.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _chip.withValues(alpha: 0.6)),
    ),
    child: Text(
      'iq.card.provisional'.tr(),
      style: _pop(12, color: _chip, w: FontWeight.w600),
    ),
  );
}
