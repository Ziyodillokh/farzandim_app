// Matnli IQ savoli (sonlar qatori, so'z munosabati, mantiq) — shart kartasi va
// variantlar; savol turi belgisi. Sonli savolda variantlar 3 ustunli
// katakchalar, so'z va mantiqda — to'liq kenglikdagi qatorlar. Matn bola
// tanlagan tilda (uz/ru/en).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Savol turi belgisi (aralash testda har savol ustida).
class IqKindChip extends StatelessWidget {
  const IqKindChip({super.key, required this.kind});

  final IqItemKind kind;

  static const _icons = {
    IqItemKind.figural: Icons.grid_view_rounded,
    IqItemKind.numeric: Icons.tag_rounded,
    IqItemKind.verbal: Icons.text_fields_rounded,
    IqItemKind.logic: Icons.lightbulb_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = iqKindColor(kind);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[kind], size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              iqKindLabel(kind),
              style: homeText(12.5, weight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shart: birinchi qator — ko'rsatma (kichik), qolgani — savol (katta).
/// Bitta qatorli shartda ko'rsatma umumiy ("To'g'ri javobni tanlang").
class IqStemCard extends StatelessWidget {
  const IqStemCard({super.key, required this.item});

  final IqItem item;

  @override
  Widget build(BuildContext context) {
    final text = item.stem?.of(context.locale.languageCode) ?? '';
    final lines = text.split('\n');
    final hasInstruction = lines.length > 1;
    final instruction = hasInstruction
        ? lines.first
        : 'iq.test.promptText'.tr();
    final body = hasInstruction ? lines.skip(1).join('\n') : text;
    final isNumeric = item.kind == IqItemKind.numeric;
    return Container(
      decoration: homeCardDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        children: [
          Text(
            instruction,
            textAlign: TextAlign.center,
            style: homeText(13.5, color: HomeColors.textDim),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: isNumeric
                ? homeDisplay(24, letterSpacing: 0.5, height: 1.3)
                : homeText(18, weight: FontWeight.w700, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class IqTextOptions extends StatelessWidget {
  const IqTextOptions({super.key, required this.item, required this.onSelect});

  final IqItem item;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    VoidCallback? tap(String key) => onSelect == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            onSelect!(key);
          };
    if (item.kind == IqItemKind.numeric) {
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          for (final o in item.options)
            _Tile(
              optionKey: o.key,
              text: o.text?.of(lang) ?? '',
              isSelected: o.key == item.choice,
              isCompact: true,
              onTap: tap(o.key),
            ),
        ],
      );
    }
    return Column(
      children: [
        for (final o in item.options) ...[
          _Tile(
            optionKey: o.key,
            text: o.text?.of(lang) ?? '',
            isSelected: o.key == item.choice,
            isCompact: false,
            onTap: tap(o.key),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.optionKey,
    required this.text,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  final String optionKey;
  final String text;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? HomeColors.primary : HomeColors.ringTrack,
        shape: BoxShape.circle,
      ),
      child: Text(optionKey, style: homeText(12, weight: FontWeight.w800)),
    );
    final label = Text(
      text,
      textAlign: isCompact ? TextAlign.center : TextAlign.start,
      style: isCompact
          ? homeDisplay(20, weight: FontWeight.w700)
          : homeText(15, weight: FontWeight.w600, height: 1.35),
    );
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$optionKey. $text',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: isCompact
              ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
              : const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: isSelected
                ? HomeColors.primary.withValues(alpha: 0.18)
                : HomeColors.tile,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? HomeColors.primary : HomeColors.tileBorder,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: isCompact
              ? Stack(
                  children: [
                    Align(alignment: Alignment.topLeft, child: badge),
                    Center(child: label),
                  ],
                )
              : Row(
                  children: [
                    badge,
                    const SizedBox(width: 12),
                    Expanded(child: label),
                  ],
                ),
        ),
      ),
    );
  }
}
