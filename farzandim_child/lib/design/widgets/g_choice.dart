// Tanlov elementlari: segment (`.segc`), kalit (`.sw`), variant qatori (`.opt`),
// son tanlagich (yosh −/+), qadamlar ro'yxati (`.steps`).

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:farzandim_child/design/tokens.dart';
import 'package:farzandim_child/design/typography.dart';
import 'package:farzandim_child/design/widgets/g_glass.dart';
import 'package:farzandim_child/design/widgets/g_pressable.dart';
import 'package:flutter/widgets.dart';

const _segmentOn = Color(0x384F86FF);
const _segmentOnBorder = Color(0x738CB4FF);

/// Bir nechta teng variantdan bittasini tanlash (til, jins, davr).
class GSegmented<T> extends StatelessWidget {
  const GSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
  });

  final List<T> options;

  /// `null` — hech narsa tanlanmagan (masalan jins oldindan tanlanmaydi).
  final T? selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _segment(options[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment(T option) {
    final on = option == selected;
    return GPressable(
      onTap: () => onChanged(option),
      selected: on,
      exclusive: true,
      semanticLabel: labelOf(option),
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? _segmentOn : null,
          borderRadius: BorderRadius.circular(GRadius.segment),
          border: Border.all(
            color: on ? _segmentOnBorder : const Color(0x00FFFFFF),
          ),
        ),
        child: Text(
          labelOf(option),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GText.onest(
            14,
            weight: FontWeight.w600,
            color: on ? GColors.white : const Color(0xFFB4C0DA),
          ),
        ),
      ),
    );
  }
}

/// Yoqish/o'chirish kaliti, 50×30.
///
/// `GListItem` ichida `semanticLabel` bermang — qator sarlavhasi nom bo'ladi
/// (aks holda ekran o'quvchi nomni ikki marta o'qiydi).
class GSwitch extends StatelessWidget {
  const GSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GPressable(
        isButton: false,
        haptic: true,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        // Bosish zonasi 48px balandlikda, ko'rinish 50×30.
        child: SizedBox(
          height: GSpace.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: value ? null : const Color(0x24FFFFFF),
                gradient: value
                    ? const LinearGradient(
                        begin: Alignment(-.5, -.87),
                        end: Alignment(.5, .87),
                        colors: [GColors.primary, GColors.primaryMid],
                      )
                    : null,
              ),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: GColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4D000000),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Katta variant qatori (javob, sabab, akkaunt): radio doirasi + matn.
class GOption extends StatelessWidget {
  const GOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.subtitle,
    this.showRadio = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final String? subtitle;
  final bool showRadio;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(GRadius.option);
    return GPressable(
      onTap: onTap,
      selected: selected,
      exclusive: showRadio,
      semanticLabel: subtitle == null ? label : '$label, $subtitle',
      haptic: true,
      child: GOuterShadow(
        borderRadius: radius,
        shadows: selected ? GOuterShadow.ring(GColors.focusRing) : const [],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? const Color(0xB38CB4FF)
                  : const Color(0x17FFFFFF),
            ),
            gradient: gradientOver(
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [Color(0x424F86FF), Color(0x1F2F5BEA)]
                    : const [Color(0x0DFFFFFF), Color(0x04FFFFFF)],
              ),
              GColors.glassFill,
            ),
          ),
          child: Row(
            children: [
              if (showRadio) ...[
                _Radio(on: selected),
                const SizedBox(width: 14),
              ],
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GText.onest(15, weight: FontWeight.w600),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: GText.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? const Color(0x4D4F86FF) : null,
        border: Border.all(
          color: on ? GColors.link : const Color(0x38FFFFFF),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: on
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: GColors.white,
              ),
            )
          : null,
    );
  }
}

/// Son tanlagich: [−] qiymat [+]. `value == null` bo'lsa «—» ko'rsatiladi.
class GStepper extends StatelessWidget {
  const GStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.unit,
    this.fallback,
  });

  final int? value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String decreaseLabel;
  final String increaseLabel;
  final String? unit;

  /// Qiymat bo'lmaganda bosilsa boshlanadigan son.
  final int? fallback;

  @override
  Widget build(BuildContext context) {
    final current = value;
    final start = current ?? fallback ?? min;
    final canDecrease = current == null || current > min;
    final canIncrease = current == null || current < max;
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: GIcons.minus,
            label: decreaseLabel,
            onTap: canDecrease
                ? () => onChanged(current == null ? start : current - 1)
                : null,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text.rich(
                TextSpan(
                  text: current?.toString() ?? '—',
                  children: [
                    if (current != null && unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: GText.onest(
                          13,
                          weight: FontWeight.w600,
                          color: GColors.textMuted,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: GText.display(18),
              ),
            ),
          ),
          _StepButton(
            icon: GIcons.plus,
            label: increaseLabel,
            onTap: canIncrease
                ? () => onChanged(current == null ? start : current + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final GIconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GPressable(
      onTap: onTap,
      semanticLabel: label,
      haptic: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GRadius.segment),
          color: enabled ? const Color(0x12FFFFFF) : const Color(0x08FFFFFF),
        ),
        alignment: Alignment.center,
        child: GIcon(
          icon,
          size: 18,
          secondaryOpacity: 0,
          color: enabled ? GColors.text : GColors.textFaint,
        ),
      ),
    );
  }
}

enum GStepState { todo, done, now, warn }

class GStepItem {
  const GStepItem({
    required this.title,
    this.subtitle,
    this.state = GStepState.todo,
    this.stateLabel,
  });

  final String title;
  final String? subtitle;
  final GStepState state;

  /// Holat nomi ekran o'quvchi uchun («Bajarildi», «Hozir»): holat faqat rang bilan berilmasin.
  final String? stateLabel;
}

/// Bosqichlar (so'rov holati, ulanish): nuqta + vertikal chiziq.
class GSteps extends StatelessWidget {
  const GSteps({super.key, required this.items});

  final List<GStepItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _row(items[i], isLast: i == items.length - 1),
      ],
    );
  }

  Widget _row(GStepItem item, {required bool isLast}) {
    final (fill, border, color) = switch (item.state) {
      GStepState.todo => (
        const Color(0x0FFFFFFF),
        const Color(0x24FFFFFF),
        GColors.textFaint,
      ),
      GStepState.done => (
        const Color(0x2E10B981),
        const Color(0x806EE7B7),
        const Color(0xFF8BE8C0),
      ),
      GStepState.now => (
        const Color(0x384F86FF),
        const Color(0xCC96B9FF),
        GColors.white,
      ),
      GStepState.warn => (
        const Color(0x29F59E0B),
        const Color(0x80FCD34D),
        const Color(0xFFFFD27A),
      ),
    };
    final icon = switch (item.state) {
      GStepState.done => GIcons.check,
      GStepState.warn => GIcons.warning,
      _ => null,
    };
    final spoken = [
      item.title,
      if (item.stateLabel != null) item.stateLabel!,
      if (item.subtitle != null) item.subtitle!,
    ];
    return Semantics(
      label: spoken.join(', '),
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    GOuterShadow(
                      borderRadius: BorderRadius.circular(14),
                      shadows: item.state == GStepState.now
                          ? GOuterShadow.ring(GColors.focusRing)
                          : const [],
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fill,
                          border: Border.all(
                            color: border,
                            width: item.state == GStepState.now ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: icon != null
                            ? GIcon(
                                icon,
                                size: 15,
                                color: color,
                                secondaryOpacity: 0,
                              )
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                      ),
                    ),
                    if (!isLast)
                      const Expanded(
                        child: SizedBox(
                          width: 1,
                          child: ColoredBox(color: Color(0x1FFFFFFF)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GText.onest(14.5, weight: FontWeight.w700),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(item.subtitle!, style: GText.caption),
                      ],
                    ],
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
