// "Kelajak profilim" bo'laklari: mavzu bo'yicha oldingi va oxirgi natija
// (oddiy chiziqlar, o'zgarish belgisi bilan), o'sgan qiziqishlar va
// yechilgan testlar qatori. Foiz belgisi yo'q — faqat chiziq va farq.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_palette.dart';
import 'package:flutter/material.dart';

/// Oldingi natija chizig'i rangi.
const _previousColor = Color(0xFF5B6B80);

/// Shu farqdan boshlab mavzu "o'sgan" (server `improved` bilan bir xil).
const _improvedDelta = 10;

/// "Oldin" / "Hozir" belgilari.
class KelajakBarsLegend extends StatelessWidget {
  const KelajakBarsLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(key.tr(), style: homeText(12, color: HomeColors.textDim)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(_previousColor, 'kelajak.progress.before'),
        item(HomeColors.primary, 'kelajak.progress.now'),
      ],
    );
  }
}

/// Mavzu qatori: nom, o'zgarish belgisi va ikki chiziq (oldin / hozir).
class KelajakCategoryDeltaRow extends StatelessWidget {
  const KelajakCategoryDeltaRow({super.key, required this.category});

  final KelajakProgressCategory category;

  @override
  Widget build(BuildContext context) {
    final previous = category.previous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                category.name.inLocale(context),
                style: homeText(13.5, weight: FontWeight.w600, height: 1.3),
              ),
            ),
            const SizedBox(width: 10),
            KelajakDeltaLabel(previous: previous, delta: category.delta),
          ],
        ),
        const SizedBox(height: 8),
        if (previous != null) ...[
          _Bar(value: previous, color: _previousColor, height: 4),
          const SizedBox(height: 4),
        ],
        _Bar(value: category.latest, color: HomeColors.primary, height: 8),
      ],
    );
  }
}

/// O'zgarish: "+25" (o'sdi), "−10", "O'zgarmadi" yoki "Birinchi natija".
class KelajakDeltaLabel extends StatelessWidget {
  const KelajakDeltaLabel({super.key, this.previous, this.delta});

  final int? previous;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final delta = previous == null ? null : this.delta;
    final (text, color) = switch (delta) {
      null => ('kelajak.progress.first'.tr(), HomeColors.textDim),
      0 => ('kelajak.progress.same'.tr(), HomeColors.textDim),
      final int d when d > 0 => (
        '+$d',
        d >= _improvedDelta ? HomeColors.green : HomeColors.text,
      ),
      final int d => ('−${-d}', HomeColors.textDim),
    };
    return Text(
      text,
      style: homeText(12.5, weight: FontWeight.w700, color: color),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.height});

  /// 0..100.
  final int value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: QuizColors.segmentTrack),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (value / 100).clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yechilgan test qatori: nom, sana va javoblar soni.
class KelajakHistoryRow extends StatelessWidget {
  const KelajakHistoryRow({super.key, required this.item});

  final KelajakSessionSummary item;

  @override
  Widget build(BuildContext context) {
    final day = item.day;
    final details = [
      if (day != null) localizedDayMonth(day),
      if (item.total > 0)
        'kelajak.progress.historyItem'.tr(
          namedArgs: {'answered': '${item.answered}', 'total': '${item.total}'},
        ),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: HomeColors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title?.inLocale(context) ?? 'kelajak.title'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(14, weight: FontWeight.w700),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: homeText(12.5, color: HomeColors.textDim),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
