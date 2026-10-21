// "Bola ovozi" savoli: "Savol 2/5", savol matni va 1–5 shkala (belgi +
// yorliq: "Yo'q" … "Ha, juda"). Har savolga javob majburiy.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:flutter/material.dart';

class SurveyQuestionCard extends StatelessWidget {
  const SurveyQuestionCard({
    super.key,
    required this.number,
    required this.total,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  /// Savol tartibi (1 dan) va jami.
  final int number;
  final int total;
  final String text;

  /// Tanlangan baho (1..5) — `null`: hali javob yo'q.
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isAnswered = value != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAnswered
              ? HomeColors.primary.withValues(alpha: 0.45)
              : HomeColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'learn.questionOf'.tr(
              namedArgs: {'current': '$number', 'total': '$total'},
            ),
            style: homeText(
              12.5,
              weight: FontWeight.w700,
              color: HomeColors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: homeText(16, weight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 12),
          SurveyScale(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 1–5 shkala: beshta teng tugma.
class SurveyScale extends StatelessWidget {
  const SurveyScale({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Bir xil balandlik — yorliq ikki qatorga o'tsa ham tugmalar teng.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in surveyScaleValues) ...[
            if (option != surveyScaleValues.first) const SizedBox(width: 6),
            Expanded(
              child: _ScaleOption(
                value: option,
                isSelected: option == value,
                onTap: () => onChanged(option),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScaleOption extends StatelessWidget {
  const _ScaleOption({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  final int value;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = surveyScaleLabelKey(value).tr();
    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(2, 9, 2, 8),
          decoration: BoxDecoration(
            color: isSelected
                ? HomeColors.primary.withValues(alpha: 0.2)
                : HomeColors.tile,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? HomeColors.primary : HomeColors.tileBorder,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Och fon — qorong'i "yangi oy" ham ko'rinsin.
                  color: Colors.white.withValues(
                    alpha: isSelected ? 0.22 : 0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  surveyScaleEmoji(value),
                  style: const TextStyle(fontSize: 21, height: 1.1),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: homeText(
                  11,
                  weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? HomeColors.text : HomeColors.textDim,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
