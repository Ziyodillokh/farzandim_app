// ─────────────────────────────────────────────────────────────────────
// GrowthReportCard — "Hisobotlar"dagi Bilim o'sishi kartasi
// ─────────────────────────────────────────────────────────────────────
//
// So'nggi 7 kun: testlar soni va o'rtacha natija; bosilsa Growth sahifasi
// (`AppRoutes.growthPath`). Yuklanayotganda, xatoda yoki Growth backend'da
// yo'q bo'lsa (404 `code`siz) karta ko'rsatilmaydi va joy ham olmaydi.
// Uslub `reports_screen` kartalari bilan bir xil (#12171E, radius 20).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);
const _violet = Color(0xFFA78BFA);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.35);

/// Karta ostidagi qisqa matn: test bo'lsa — davr, soni va o'rtacha natija.
String growthReportSubtitle(LearningSummary summary) {
  if (!summary.hasTests) return 'growth.card.empty'.tr();
  return 'growth.card.summary'.tr(
    namedArgs: {
      'days': '${summary.periodDays}',
      'count': '${summary.testsCount}',
      'percent': growthPercentLabel(summary.overallPercent),
    },
  );
}

class GrowthReportCard extends ConsumerWidget {
  const GrowthReportCard({
    required this.childId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String childId;

  /// Karta ko'ringandagina qo'llanadigan tashqi bo'shliq.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(
          growthSummaryProvider((childId: childId, days: kGrowthPeriods.first)),
        )
        .valueOrNull;
    if (summary == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.growthPath(childId)),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _chipBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsBold.graphUp,
                    size: 22,
                    color: _violet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'growth.title'.tr(),
                        style: _pop(15.5, w: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        growthReportSubtitle(summary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(13, c: _dim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 20,
                  color: _dim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
