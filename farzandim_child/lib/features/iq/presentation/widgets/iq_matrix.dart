// Matritsa va javob variantlari — serverdan kelgan SVG (oq kataklar, to'q
// shakllar) qorong'i fonda oq kartada ko'rsatiladi.

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Matritsa kartasi kengligi chegarasi (planshetda haddan katta bo'lmasin).
const _kMaxGridWidth = 340.0;

class IqMatrixGrid extends StatelessWidget {
  const IqMatrixGrid({super.key, required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxGridWidth),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: SvgPicture.string(svg, excludeFromSemantics: true),
          ),
        ),
      ),
    );
  }
}

class IqOptions extends StatelessWidget {
  const IqOptions({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<IqOption> options;
  final String? selected;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: [
        for (final option in options)
          _OptionTile(
            option: option,
            isSelected: option.key == selected,
            onTap: onSelect == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onSelect!(option.key);
                  },
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final IqOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.key,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? HomeColors.primary : Colors.transparent,
                    width: 3.5,
                  ),
                ),
                child: SvgPicture.string(
                  option.svg,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.key,
              style: homeText(
                13,
                weight: FontWeight.w700,
                color: isSelected ? HomeColors.blue : HomeColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
