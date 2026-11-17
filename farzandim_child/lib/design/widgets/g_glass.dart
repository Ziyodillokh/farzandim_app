// Shisha yuza (`.g`) va ajratilgan karta (`.feat`).
//
// Unumdorlik qarori: kanvasdagi backdrop-filter blur kartalarda ishlatilmaydi.
// Fon faqat yumshoq orblardan iborat, shuning uchun yarim shaffof to'q fill +
// och qatlam + gradient halqa vizual jihatdan bir xil natija beradi, arzon
// Android qurilmalarda esa har karta uchun blur qatlami kadrlarni tushiradi.

import 'package:farzandim_child/design/tokens.dart';
import 'package:flutter/widgets.dart';

enum GGlassKind { plain, feat }

class GGlass extends StatelessWidget {
  const GGlass({
    super.key,
    required this.child,
    this.kind = GGlassKind.plain,
    this.radius = GRadius.card,
    this.padding = const EdgeInsets.all(GSpace.cardPad),
    this.glowHue,
    this.shadow = true,
  });

  final Widget child;
  final GGlassKind kind;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// `feat` kartaning yuqori o'ng burchagidagi rangli nur (standart: ko'k).
  final GHue? glowHue;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final isFeat = kind == GGlassKind.feat;
    final borderRadius = BorderRadius.circular(radius);
    final glow = (glowHue ?? GHue.blue).base;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: isFeat ? GColors.featFill : GColors.glassFill,
      ),
      child: CustomPaint(
        foregroundPainter: GRingPainter(
          radius: radius,
          gradient: isFeat ? GEffects.featRing : GEffects.glassRing,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: GEffects.glassSheen,
              borderRadius: borderRadius,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isFeat
                    ? RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.1,
                        colors: [
                          glow.withValues(alpha: .20),
                          glow.withValues(alpha: 0),
                        ],
                        stops: const [0, .7],
                      )
                    : null,
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
    if (!shadow) return card;
    return GOuterShadow(
      borderRadius: borderRadius,
      shadows: GEffects.glassShadow,
      child: card,
    );
  }
}

/// Faqat shakl TASHQARISIGA chiziladigan soya yoki halqa.
///
/// Flutter `BoxShadow`ni butun quti ostiga chizadi; yarim shaffof shisha
/// orqali u ko'rinib, kartani qoraytiradi va fondagi orb rangini yo'qotadi
/// (CSS'da soya faqat tashqarida). Fokus halqalari ham shu bilan chiziladi.
class GOuterShadow extends StatelessWidget {
  const GOuterShadow({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.shadows,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  /// Fokus halqasi: tashqariga [width] px, xiralashtirilmagan.
  static List<BoxShadow> ring(Color color, {double width = 4}) => [
    BoxShadow(color: color, spreadRadius: width),
  ];

  @override
  Widget build(BuildContext context) {
    // Tuzilma doim bir xil: halqa paydo bo'lganda bola qayta yaratilmaydi
    // (aks holda fokus olgan matn maydoni klaviatura ulanishini yo'qotadi).
    return CustomPaint(
      painter: shadows.isEmpty
          ? null
          : _OuterShadowPainter(borderRadius, shadows),
      child: child,
    );
  }
}

class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter(this.borderRadius, this.shadows);

  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = borderRadius.toRRect(rect);
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(160)),
        Path()..addRRect(shape),
      ),
    );
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.borderRadius != borderRadius || old.shadows != shadows;
}

/// 1px gradient halqa (kanvasdagi maskalangan `::before`).
class GRingPainter extends CustomPainter {
  const GRingPainter({
    required this.radius,
    required this.gradient,
    this.width = 1,
  });

  final double radius;
  final Gradient gradient;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = gradient.createShader(rect);
    final inset = width / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(inset),
        Radius.circular(radius - inset),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(GRingPainter old) =>
      old.radius != radius || old.gradient != gradient || old.width != width;
}

/// Ichki chegara (CSS `inset 0 0 0 1px`) — tile, chip va eslatmalar uchun.
class GInsetBorder extends StatelessWidget {
  const GInsetBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
    this.fill,
    this.gradient,
    this.width = 1,
  });

  final Widget child;
  final Color color;
  final double radius;
  final Color? fill;
  final Gradient? gradient;
  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? fill : null,
        gradient: gradientOver(gradient, fill),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color,
          width: width,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: child,
    );
  }
}
