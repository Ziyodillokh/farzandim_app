// Kunlik reja qatori (B01 va U03): fan plitasi, nomi, izoh va holat
// (bajarildi belgisi / «Navbatda» / taxminiy daqiqa).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/growth/common/learning_rules.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:flutter/material.dart';

class PlanRow extends StatelessWidget {
  const PlanRow({
    super.key,
    required this.item,
    required this.isNext,
    this.lines,
  });

  final DailyPlanItem item;
  final bool isNext;

  /// Izoh o'rniga bir nechta qator (U03: «Foizlar · yangi mavzu», «… · takror»).
  final List<String>? lines;

  @override
  Widget build(BuildContext context) {
    final result = item.result;
    final subtitle = result != null
        ? 'g5.today.mission.rowDone'.tr(
            namedArgs: {
              'correct': '${result.correct}',
              'total': '${result.total}',
            },
          )
        : 'g5.today.mission.rowQuestions'.tr(
            namedArgs: {'count': '${item.questionCount}'},
          );
    final Widget trailing;
    if (result != null) {
      trailing = Semantics(
        label: 'g5.today.mission.rowDoneA11y'.tr(),
        child: const GIcon(
          GIcons.checkCircle,
          size: 22,
          color: Color(0xFF5EE0A8),
        ),
      );
    } else if (isNext) {
      trailing = GChip(
        label: 'g5.today.mission.rowNext'.tr(),
        kind: GChipKind.info,
      );
    } else {
      trailing = Text(
        'g5.today.mission.rowMinutes'.tr(
          namedArgs: {'count': '$kMinutesPerSubject'},
        ),
        style: GText.onest(
          12,
          weight: FontWeight.w600,
          color: GColors.textMuted,
        ),
      );
    }
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isNext ? const Color(0x1A4F86FF) : null,
          border: Border.all(
            color: isNext ? const Color(0x528CB4FF) : const Color(0x00FFFFFF),
          ),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: result != null ? .75 : 1,
              child: subjectTile(item.subject),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.subject.label,
                    style: GText.onest(
                      14.5,
                      weight: FontWeight.w700,
                      color: result != null ? GColors.textLabel : GColors.text,
                    ),
                  ),
                  for (final line in lines ?? [subtitle]) ...[
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: GText.onest(
                        12,
                        color: isNext
                            ? const Color(0xFFB8C6E6)
                            : GColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
