// Bajarilgan fan belgisi: ikon burchagida yashil ✓.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

const _doneGreen = Color(0xFF45E2BE);

class DoneBadgeIcon extends StatelessWidget {
  const DoneBadgeIcon({super.key, required this.done, required this.child});

  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!done) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            decoration: const BoxDecoration(
              color: HomeColors.bg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              SolarIconsBold.checkCircle,
              size: 15,
              color: _doneGreen,
            ),
          ),
        ),
      ],
    );
  }
}
