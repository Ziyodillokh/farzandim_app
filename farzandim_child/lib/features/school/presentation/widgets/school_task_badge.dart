// "Maktab topshirig'i" belgisi: fan ikonkasi burchagida akademik qalpoq —
// maktab shu fandan test bergan va u hali yechilmagan ("Bugungi testlar"
// plitkalari: bosh sahifa va Testlar sahifasi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolTaskBadge extends StatelessWidget {
  const SchoolTaskBadge({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Semantics(
      label: 'school.assignments.badge'.tr(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: SchoolColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: HomeColors.bg, width: 1.5),
              ),
              child: const Icon(
                SolarIconsBold.squareAcademicCap,
                size: 10,
                color: HomeColors.bg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
