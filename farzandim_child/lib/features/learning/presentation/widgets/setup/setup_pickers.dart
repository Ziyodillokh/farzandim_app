// Sinf, fanlar va qiziqishlar tanlovi (LearningSetupScreen qadamlari).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:flutter/material.dart';

/// Ustunlar sonidagi teng enli to'r (oxirgi qator chapdan to'ladi).
class _EvenGrid extends StatelessWidget {
  const _EvenGrid({required this.columns, required this.children});

  static const gap = 10.0;

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row * columns < children.length; row++) ...[
          if (row > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: gap),
                  Expanded(
                    child: row * columns + col < children.length
                        ? children[row * columns + col]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class GradePicker extends StatelessWidget {
  const GradePicker({super.key, required this.grade, required this.onChanged});

  final int? grade;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EvenGrid(
      columns: 4,
      children: [
        for (var g = kMinGrade; g <= kMaxGrade; g++)
          SelectTile(
            selected: grade == g,
            showCheck: false,
            onTap: () => onChanged(g),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$g', style: homeDisplay(26, height: 1.1)),
                  const SizedBox(height: 2),
                  FitText(
                    'learn.gradeWord'.tr(),
                    style: homeText(12.5, color: HomeColors.textDim),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SubjectPicker extends StatelessWidget {
  const SubjectPicker({
    super.key,
    required this.available,
    required this.selected,
    required this.onToggle,
  });

  final List<Subject> available;
  final List<Subject> selected;
  final ValueChanged<Subject> onToggle;

  @override
  Widget build(BuildContext context) {
    return _EvenGrid(
      columns: 2,
      children: [
        for (final s in available)
          SelectTile(
            selected: selected.contains(s),
            onTap: () => onToggle(s),
            child: Row(
              children: [
                SubjectIcon(subject: s, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: FitText(
                      s.labelKey.tr(),
                      style: homeText(14.5, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class InterestPicker extends StatelessWidget {
  const InterestPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _EvenGrid(
      columns: 2,
      children: [
        for (final o in kInterestOptions)
          SelectTile(
            selected: selected.contains(o.id),
            onTap: () => onToggle(o.id),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(o.icon, size: 21, color: o.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: FitText(
                      o.label(),
                      style: homeText(14.5, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
