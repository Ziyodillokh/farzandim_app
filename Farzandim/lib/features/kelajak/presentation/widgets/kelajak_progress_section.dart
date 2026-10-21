// ─────────────────────────────────────────────────────────────────────
// KelajakProgressSection — oxirgi natija oldingisiga nisbatan
// ─────────────────────────────────────────────────────────────────────
//
// Har kategoriya: nomi, oxirgi ball chizig'i (raqamsiz) va o'zgarish
// ("+25" yashil, "−10" to'q sariq, "O'zgarmadi", "Birinchi natija").
// Pastda qiziqishi sezilarli ortgan yo'nalishlar (delta ≥ 10). Foiz
// belgisi va qizil rang ishlatilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_progress.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ball chizig'ining to'liq qiymati.
const double _fullScore = 100;

class KelajakProgressSection extends StatelessWidget {
  const KelajakProgressSection({required this.progress, super.key});

  final KelajakProgress progress;

  @override
  Widget build(BuildContext context) {
    final rising = kelajakRisingInterests(progress);
    if (progress.categories.isEmpty && rising.isEmpty) {
      return const SizedBox.shrink();
    }
    return KelajakSection(
      icon: SolarIconsBold.graphNewUp,
      iconColor: kelajakGreen,
      title: 'kelajak.progress.title'.tr(),
      hint: progress.categories.isEmpty ? null : 'kelajak.progress.hint'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...kelajakSpaced(
            progress.categories.map((c) => _CategoryRow(category: c)),
            gap: 14,
          ),
          if (rising.isNotEmpty) ...[
            if (progress.categories.isNotEmpty) const SizedBox(height: 16),
            Text(
              'kelajak.progress.rising'.tr(),
              style: kelajakPop(12.5, w: FontWeight.w600, c: kelajakDim),
            ),
            const SizedBox(height: 6),
            KelajakChipWrap(
              icon: SolarIconsBold.roundArrowUp,
              labels: [for (final i in rising) kelajakText(context, i.name)],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final KelajakProgressCategory category;

  @override
  Widget build(BuildContext context) {
    final name = kelajakText(context, category.name);
    final change = _ChangeLabel.of(category.delta);
    return Semantics(
      label: '$name, ${change.text}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? category.category : name,
                  style: kelajakPop(13.5, w: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                change.text,
                style: kelajakPop(12.5, w: FontWeight.w600, c: change.color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: category.latest / _fullScore,
            minHeight: 6,
            color: kelajakBlue,
            backgroundColor: kelajakTrack,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }
}

/// O'zgarish yorlig'i va rangi.
@immutable
class _ChangeLabel {
  const _ChangeLabel(this.text, this.color);

  factory _ChangeLabel.of(int? delta) {
    if (delta == null) {
      return _ChangeLabel('kelajak.progress.first'.tr(), kelajakDim);
    }
    return switch (growthTrendOf(delta)) {
      GrowthTrend.up => _ChangeLabel(kelajakDeltaLabel(delta), kelajakGreen),
      GrowthTrend.down => _ChangeLabel(kelajakDeltaLabel(delta), kelajakOrange),
      GrowthTrend.flat => _ChangeLabel(
        'kelajak.progress.same'.tr(),
        kelajakDim,
      ),
    };
  }

  final String text;
  final Color color;
}
