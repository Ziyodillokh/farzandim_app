// «Farzandim maktabda» sarlavhasi: avatar, ism, sinf · maktab va davr
// belgisi. Davr belgisi ism ostida turadi — ism kartaning butun
// kengligini oladi: oddiy shriftda bir qator, tor ekran yoki katta
// shriftda ko'pi bilan ikki qator.

import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_text_fit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class OverviewHeaderCard extends StatelessWidget {
  const OverviewHeaderCard({
    required this.student,
    required this.periodLabel,
    super.key,
  });

  final ConnectStudent student;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      student.className,
      student.schoolName,
    ].where((e) => e.isNotEmpty).join(' · ');
    return SkCard(
      tint: SK.blue,
      child: Row(
        children: [
          SkAvatar(name: student.name, color: SK.blue, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkWordSafeText(
                  student.name,
                  style: skDisplay(17, w: FontWeight.w500),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: skText(13, c: SK.dim, height: 1.4),
                  ),
                ],
                const SizedBox(height: 8),
                SkTag(
                  label: periodLabel,
                  icon: SolarIconsBold.calendarMinimalistic,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
