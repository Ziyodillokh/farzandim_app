// Tor ekran va katta shriftga chidamli matn joylashuvi: ism so'z
// o'rtasidan uzilmaydi (harflar ustunga tushmaydi), qatordagi yorliq
// yonidagi matndan joy tortib olmaydi, karta to'ri matn bilan birga o'sadi.

import 'dart:math' as math;

import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:flutter/material.dart';

/// Yorliq qator kengligining ko'pi bilan shuncha ulushini oladi; ko'proq
/// kerak bo'lsa matn ostiga tushadi.
const double _maxTagShare = 0.42;

/// Shrift kichrayishining pastki chegarasi (asl o'lchamga nisbatan).
const double _minShrink = 0.72;

/// Qator: chapda [leading] (matn), o'ngda [tag]. Yorliq sig'sa — o'ngda,
/// sig'masa (tor ekran, katta shrift) — matn ostida; ikkala holatda ham
/// matn to'liq so'zlar bilan qatorlanadi.
class SkTagRow extends StatelessWidget {
  const SkTagRow({
    required this.leading,
    required this.tag,
    this.gap = 8,
    super.key,
  });

  final Widget leading;
  final SkTag tag;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            tag.naturalWidth(context) <= constraints.maxWidth * _maxTagShare;
        if (fits) {
          return Row(
            children: [
              Expanded(child: leading),
              SizedBox(width: gap),
              tag,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(height: 6),
            SkTag(
              label: tag.label,
              color: tag.color,
              icon: tag.icon,
              maxLines: 2,
            ),
          ],
        );
      },
    );
  }
}

/// Ism yoki sarlavha: ko'pi bilan [maxLines] qator, so'z o'rtasidan
/// uzilmaydi — eng uzun so'z kenglikka sig'masa, shrift asl o'lchamning
/// 72% igacha kichrayadi.
class SkWordSafeText extends StatelessWidget {
  const SkWordSafeText(
    this.text, {
    required this.style,
    this.maxLines = 2,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: wordSafeStyle(
          text,
          style,
          maxWidth: constraints.maxWidth,
          scaler: MediaQuery.textScalerOf(context),
          direction: Directionality.of(context),
        ),
      ),
    );
  }
}

/// [style] — [text] ning eng uzun so'zi [maxWidth] ga sig'adigan qilib
/// kichraytirilgan (kerak bo'lmasa o'zi).
TextStyle wordSafeStyle(
  String text,
  TextStyle style, {
  required double maxWidth,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  final base = style.fontSize;
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (base == null || words.isEmpty || !maxWidth.isFinite) return style;

  double widestWord(double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: words.join('\n'),
        style: style.copyWith(fontSize: size),
      ),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  final floor = base * _minShrink;
  var size = base;
  var width = widestWord(size);
  while (width > maxWidth && size > floor) {
    size = math.max(floor, math.min(size - 0.5, size * maxWidth / width));
    width = widestWord(size);
  }
  return size == base ? style : style.copyWith(fontSize: size);
}

/// Ikki ustunli kartalar: har qator balandligi — undagi eng baland karta
/// (kamida [aspectRatio] bo'yicha). GridView'ning qat'iy nisbatidan farqli,
/// katta shriftda karta matni kesilmaydi.
class SkTwoColumnRows extends StatelessWidget {
  const SkTwoColumnRows({
    required this.children,
    this.spacing = 10,
    this.aspectRatio = 1,
    super.key,
  });

  final List<Widget> children;
  final double spacing;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - spacing) / 2;
        final minHeight = cellWidth / aspectRatio;
        return Column(
          children: [
            for (var i = 0; i < children.length; i += 2) ...[
              if (i > 0) SizedBox(height: spacing),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: children[i]),
                      SizedBox(width: spacing),
                      Expanded(
                        child: i + 1 < children.length
                            ? children[i + 1]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
