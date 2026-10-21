// ─────────────────────────────────────────────────────────────────────
// KelajakCareerLabSection — sinab ko'rilgan faoliyatlar va taassurot
// ─────────────────────────────────────────────────────────────────────
//
// Ota-onaga faqat faoliyat nomi va xulosa (yoqdi / o'rtacha / unchalik
// yoqmadi) — savol id'si va xom reyting yo'q. Faoliyat yo'nalishi
// (RIASEC) qiziqishlar profilidagi nomi bilan ("Amaliy") ko'rsatiladi.
// Keyingi sinov — backend tavsiyasi (`next[].kind == career_lab`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_insights.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakCareerLabSection extends StatelessWidget {
  const KelajakCareerLabSection({required this.summary, super.key});

  final KelajakSummary summary;

  @override
  Widget build(BuildContext context) {
    final view = KelajakCareerLabView.of(summary.insights);
    if (view.isEmpty) return const SizedBox.shrink();
    final interests = summary.interests;
    Widget group(
      String labelKey,
      IconData icon,
      List<KelajakDirection> items,
    ) => _DirectionGroup(
      label: labelKey.tr(),
      icon: icon,
      items: [
        for (final item in items)
          (
            activity: kelajakText(context, item.activity),
            direction: kelajakText(context, interests?.nameOf(item.code)),
          ),
      ],
    );
    return KelajakSection(
      icon: SolarIconsBold.routing,
      iconColor: kelajakBlue,
      title: 'kelajak.careerLab.title'.tr(),
      hint: 'kelajak.careerLab.hint'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kelajakSpaced([
          if (view.liked.isNotEmpty)
            group('kelajak.careerLab.liked', SolarIconsBold.like, view.liked),
          if (view.neutral.isNotEmpty)
            group(
              'kelajak.careerLab.neutral',
              SolarIconsBold.minusCircle,
              view.neutral,
            ),
          if (view.disliked.isNotEmpty)
            group(
              'kelajak.careerLab.disliked',
              SolarIconsBold.dislike,
              view.disliked,
            ),
          if (view.next.isNotEmpty) _NextTry(steps: view.next),
        ], gap: 14),
      ),
    );
  }
}

typedef _DirectionRow = ({String activity, String direction});

/// Bir xil taassurotli faoliyatlar guruhi.
class _DirectionGroup extends StatelessWidget {
  const _DirectionGroup({
    required this.label,
    required this.icon,
    required this.items,
  });

  final String label;
  final IconData icon;
  final List<_DirectionRow> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kelajakDim),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: kelajakPop(12.5, w: FontWeight.w600, c: kelajakDim),
              ),
            ),
          ],
        ),
        for (final item in items) ...[
          const SizedBox(height: 6),
          _DirectionTile(row: item),
        ],
      ],
    );
  }
}

class _DirectionTile extends StatelessWidget {
  const _DirectionTile({required this.row});

  final _DirectionRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kelajakChipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(row.activity, style: kelajakPop(13.5))),
          if (row.direction.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(row.direction, style: kelajakPop(12, c: kelajakDim)),
          ],
        ],
      ),
    );
  }
}

/// "Keyingi sinov" — qiziqishga mos yangi faoliyat.
class _NextTry extends StatelessWidget {
  const _NextTry({required this.steps});

  final List<KelajakNextStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'kelajak.careerLab.next'.tr(),
          style: kelajakPop(12.5, w: FontWeight.w600, c: kelajakDim),
        ),
        for (final step in steps) ...[
          const SizedBox(height: 6),
          KelajakTextTile(
            title: kelajakText(context, step.title),
            body: kelajakText(context, step.body),
          ),
        ],
      ],
    );
  }
}
