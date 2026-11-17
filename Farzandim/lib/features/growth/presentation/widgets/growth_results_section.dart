// ─────────────────────────────────────────────────────────────────────
// growth_results_section — oxirgi test natijalari (sahifalangan)
// ─────────────────────────────────────────────────────────────────────
//
// `growthResultsProvider(childId)`: 30 tadan, keyingisi `nextBefore`
// kursori bilan ("Yana ko'rsatish" yoki ro'yxat oxiriga yaqinlashganda —
// ekran chaqiradi). Sahifa xatosi ro'yxat ostida, "Qayta urinish" bilan.
// Growth backend'da yo'q (404 `code`siz) — bo'lim ko'rsatilmaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/growth/presentation/widgets/growth_summary_cards.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _rowBg = Color(0x0AFFFFFF); // oq 4%
const _rowBorder = Color(0x14FFFFFF); // oq 8%
const _chipBg = Color(0xFF1B2128);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.4,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.45);

/// "Oxirgi natijalar" sarlavhasi, ro'yxat va oxiridagi holat.
class GrowthResultsSection extends ConsumerWidget {
  const GrowthResultsSection({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(growthResultsProvider(childId));
    final failure = state.failure;
    if (state.items.isEmpty && (failure?.isUnavailable ?? false)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('growth.results'.tr(), style: _unb(15)),
        ),
        const SizedBox(height: 10),
        if (state.items.isEmpty && failure == null && !state.initialLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('growth.resultsEmpty'.tr(), style: _pop(13.5, c: _dim)),
          ),
        for (final (i, result) in state.items.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          GrowthResultTile(key: ValueKey(result.id), result: result),
        ],
        _Footer(childId: childId, state: state),
      ],
    );
  }
}

/// Ro'yxat oxiri: yuklanmoqda / xato + qayta urinish / "Yana ko'rsatish".
class _Footer extends ConsumerWidget {
  const _Footer({required this.childId, required this.state});

  final String childId;
  final GrowthResultsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(growthResultsProvider(childId).notifier);
    final failure = state.failure;
    if (state.loadingMore || (state.initialLoading && state.items.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
          ),
        ),
      );
    }
    if (failure != null) {
      // Sahifa xatosida kursor saqlanadi — shu joydan davom etadi; birinchi
      // sahifa xatosida — boshidan.
      final retry = state.hasMore ? notifier.loadMore : notifier.refresh;
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchoolInlineError(message: failure.messageKey.tr()),
            const SizedBox(height: 10),
            ParvozSecondaryButton(
              label: 'common.retry'.tr(),
              onPressed: () => unawaited(retry()),
            ),
          ],
        ),
      );
    }
    if (!state.hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ParvozSecondaryButton(
        label: 'growth.loadMore'.tr(),
        onPressed: () => unawaited(notifier.loadMore()),
      ),
    );
  }
}

/// Bitta test natijasi: fan, mavzu, vaqt, foiz va to'g'ri javoblar.
class GrowthResultTile extends StatelessWidget {
  const GrowthResultTile({required this.result, super.key});

  final LearningResult result;

  @override
  Widget build(BuildContext context) {
    final color = growthLevelColor(resultLevelOf(result.percent));
    final topic = result.topic?.of(context.locale.languageCode) ?? '';
    final date = result.date;
    final duration = growthDurationLabel(result.durationSeconds);
    final meta = [
      if (date != null) schoolStampLabel(date),
      ?duration,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: _rowBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _rowBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              growthSubjectIcon(result.subject),
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        result.subject.labelKey.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(14.5, w: FontWeight.w600),
                      ),
                    ),
                    if (result.isDaily) ...[
                      const SizedBox(width: 8),
                      SchoolPill(label: 'growth.daily'.tr(), color: _blue),
                    ],
                  ],
                ),
                if (topic.isNotEmpty)
                  Text(
                    topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(12.5, c: _dim),
                  ),
                if (meta.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        SolarIconsOutline.clockCircle,
                        size: 13,
                        color: _dim,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _pop(12, c: _dim),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                growthPercentLabel(result.percent),
                style: _pop(16, w: FontWeight.w700, c: color),
              ),
              Text(
                'growth.answers'.tr(
                  namedArgs: {
                    'correct': '${result.correct}',
                    'total': '${result.total}',
                  },
                ),
                style: _pop(11.5, c: _dim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
