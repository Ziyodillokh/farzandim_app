// Fan/sinf tanlash sahifasi bo'laklari: qadam ko'rsatkichi, tanlov
// plitkasi va pastki asosiy tugma.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

const _track = Color(0xFF16222F);
const _tileBg = Color(0xFF0C1622);
const _tileBorder = Color(0x1AFFFFFF);
final _tileSelected = Color.alphaBlend(
  HomeColors.primary.withValues(alpha: 0.18),
  _tileBg,
);

/// Qadamlar chizig'i (bajarilgan va joriy — ko'k).
class SetupSteps extends StatelessWidget {
  const SetupSteps({super.key, required this.step, required this.total});

  /// 0 dan.
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= step ? HomeColors.primary : _track,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tanlanadigan plitka — tanlangani ko'k chegarali, burchakda belgi.
class SelectTile extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.showCheck = true,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: padding,
          decoration: BoxDecoration(
            // Shaffof bo'lmasin — aks holda soya ichidan ko'rinadi.
            color: selected ? _tileSelected : _tileBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? HomeColors.primary : _tileBorder,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: HomeColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              child,
              if (showCheck)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    scale: selected ? 1 : 0,
                    child: const Icon(
                      SolarIconsBold.checkCircle,
                      size: 20,
                      color: HomeColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastki asosiy tugma (52pt, to'liq enli).
class SetupButton extends StatelessWidget {
  const SetupButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled || busy ? 1 : 0.45,
      child: Material(
        color: HomeColors.primary,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 52,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FitText(
                        label,
                        style: homeText(15.5, weight: FontWeight.w700),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
