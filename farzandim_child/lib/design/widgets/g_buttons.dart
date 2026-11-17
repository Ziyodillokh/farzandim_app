// Tugmalar: asosiy (`.btn`), ikkinchi darajali shisha (`.ghost`), SOS (`.btn-sos`),
// ikon tugma (`.iconbtn`) va havola (`.link`).

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:farzandim_child/design/tokens.dart';
import 'package:farzandim_child/design/typography.dart';
import 'package:farzandim_child/design/widgets/g_pressable.dart';
import 'package:flutter/widgets.dart';

enum GButtonKind { primary, ghost, sos }

/// lg: 56 (dock asosiy tugmasi) · md: 48 (karta ichida) · second: 50 (dock ikkinchi tugmasi)
/// · xl: 64 (1–4-sinflar uchun katta tugma).
enum GButtonSize { lg, md, second, xl }

class GButton extends StatelessWidget {
  const GButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = GButtonKind.primary,
    this.size = GButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
  });

  final String label;

  /// `null` — o'chirilgan holat (kulrang, bosilmaydi).
  final VoidCallback? onPressed;
  final GButtonKind kind;
  final GButtonSize size;
  final GIconData? icon;
  final GIconData? trailingIcon;
  final bool expand;
  final bool loading;

  double get _height => switch (size) {
    GButtonSize.lg => 56,
    GButtonSize.md => 48,
    GButtonSize.second => 50,
    GButtonSize.xl => 64,
  };

  double get _radius => switch (size) {
    GButtonSize.lg => GRadius.button,
    GButtonSize.md => 16,
    GButtonSize.second => 17,
    GButtonSize.xl => 20,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final disabled = onPressed == null;
    final textStyle = switch (size) {
      GButtonSize.lg => GText.buttonLg,
      GButtonSize.md => GText.buttonMd,
      GButtonSize.second => GText.button2,
      GButtonSize.xl => GText.buttonLg.copyWith(fontSize: 19),
    };
    final foreground = disabled
        ? GColors.textFaint
        : kind == GButtonKind.ghost
        ? GColors.text
        : GColors.white;
    final iconSize = switch (size) {
      GButtonSize.lg => 19.0,
      GButtonSize.xl => 22.0,
      _ => 18.0,
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          _Spinner(color: foreground)
        else ...[
          if (icon != null) ...[
            GIcon(
              icon!,
              size: iconSize,
              color: foreground,
              secondaryOpacity: 0,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(color: foreground),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            GIcon(
              trailingIcon!,
              size: iconSize,
              color: foreground,
              secondaryOpacity: 0,
            ),
          ],
        ],
      ],
    );

    return GPressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: Container(
        height: _height,
        padding: EdgeInsets.symmetric(
          horizontal: size == GButtonSize.md ? 18 : 16,
        ),
        decoration: _decoration(disabled),
        child: content,
      ),
    );
  }

  BoxDecoration _decoration(bool disabled) {
    final radius = BorderRadius.circular(_radius);
    if (disabled) {
      return BoxDecoration(
        borderRadius: radius,
        color: const Color(0x0DFFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
      );
    }
    return switch (kind) {
      GButtonKind.primary => BoxDecoration(
        borderRadius: radius,
        gradient: GEffects.primaryGradient,
        boxShadow: GEffects.primaryShadow,
      ),
      GButtonKind.ghost => BoxDecoration(
        borderRadius: radius,
        color: const Color(0x0EFFFFFF),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      GButtonKind.sos => BoxDecoration(
        borderRadius: radius,
        gradient: GEffects.sosGradient,
        boxShadow: GEffects.sosShadow,
      ),
    };
  }
}

/// 48×48 dumaloq ikon tugma (orqaga, yopish, sozlamalar).
class GIconButton extends StatelessWidget {
  const GIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 20,
    this.ghost = true,
    this.badge = false,
    this.badgeColor = const Color(0xFFFB7185),
  });

  final GIconData icon;

  /// Ekran o'quvchi uchun majburiy nom (masalan «Orqaga»).
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool ghost;

  /// Yuqori o'ng burchakdagi nuqta (yangi xabar).
  final bool badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onPressed,
      semanticLabel: label,
      child: SizedBox.square(
        dimension: GSpace.minTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ghost ? const Color(0x0EFFFFFF) : null,
                border: ghost
                    ? Border.all(color: const Color(0x1AFFFFFF))
                    : null,
              ),
              child: SizedBox.square(
                dimension: GSpace.minTap,
                child: Center(
                  child: GIcon(
                    icon,
                    size: size,
                    secondaryOpacity: 0,
                    color: onPressed == null ? GColors.textFaint : GColors.text,
                  ),
                ),
              ),
            ),
            if (badge)
              Positioned(
                top: 11,
                right: 11,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor,
                    border: Border.all(color: GColors.bg, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Matnli havola (`.link`), 48px balandlikdagi bosiladigan zona bilan.
class GLink extends StatelessWidget {
  const GLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final GIconData? icon;
  final GIconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? GColors.textFaint : GColors.link;
    return GPressable(
      onTap: onPressed,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GSpace.minTap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              GIcon(icon!, size: 17, color: color, secondaryOpacity: 0),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label, style: GText.link.copyWith(color: color)),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              GIcon(trailingIcon!, size: 16, color: color, secondaryOpacity: 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox.square(
        dimension: 20,
        child: CustomPaint(painter: _ArcPainter(widget.color)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc((Offset.zero & size).deflate(1.2), 0, 4.2, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
