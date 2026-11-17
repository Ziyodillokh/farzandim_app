// Kichik qurilish bloklari: tile (`.t`), chip (`.chip`), eslatma (`.note`),
// progress (`.pbar`, `.segs`), avatar (`.av`) va yozishma pufagi (`.bub`).

import 'dart:math' as math;

import 'package:farzandim_child/design/icons/g_icon.dart';
import 'package:farzandim_child/design/tokens.dart';
import 'package:farzandim_child/design/typography.dart';
import 'package:flutter/widgets.dart';

/// Rangli ikon plitasi (fan, bo'lim). Burchak radiusi o'lchamning 31%.
class GTile extends StatelessWidget {
  const GTile({
    super.key,
    required this.icon,
    this.hue = GHue.blue,
    this.size = 44,
    this.iconSize,
  });

  final GIconData icon;
  final GHue hue;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = hue.base;
    final radius = BorderRadius.circular(size * .31);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: const Color(0x800A0F20),
        border: Border.all(color: c.withValues(alpha: .30)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: RadialGradient(
            center: const Alignment(-.6, -1),
            radius: 1.3,
            colors: [
              c.withValues(alpha: .30),
              c.withValues(alpha: .09),
              c.withValues(alpha: .04),
            ],
            stops: const [0, .55, 1],
          ),
        ),
        child: Center(
          child: GIcon(icon, size: iconSize ?? size * .5, color: hue.icon),
        ),
      ),
    );
  }
}

enum GChipKind {
  ok(Color(0x1F10B981), Color(0x476EE7B7), Color(0xFFBFF3DB)),
  warn(Color(0x1FF59E0B), Color(0x47FCD34D), Color(0xFFFFE3A3)),
  info(Color(0x244F86FF), Color(0x5296B9FF), Color(0xFFD3E1FF)),
  neutral(Color(0x0FFFFFFF), Color(0x1FFFFFFF), Color(0xFFC9D3EA)),
  sos(Color(0x24F43F5E), Color(0x66FF8CA0), Color(0xFFFFE1E7));

  const GChipKind(this.fill, this.border, this.text);

  final Color fill;
  final Color border;
  final Color text;
}

/// Holat belgisi: «Tasdiqlandi», «Kutilmoqda», «Yangi».
class GChip extends StatelessWidget {
  const GChip({
    super.key,
    required this.label,
    this.kind = GChipKind.neutral,
    this.icon,
  });

  final String label;
  final GChipKind kind;
  final GIconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kind.fill,
        borderRadius: BorderRadius.circular(GRadius.chip),
        border: Border.all(color: kind.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            GIcon(icon!, size: 14, color: kind.text, secondaryOpacity: 0),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GText.chip.copyWith(color: kind.text),
            ),
          ),
        ],
      ),
    );
  }
}

enum GNoteKind {
  plain(Color(0x0AFFFFFF), Color(0x14FFFFFF), Color(0xFFA9C4FF)),
  info(Color(0x1A4F86FF), Color(0x3D96B9FF), Color(0xFFA9C4FF)),
  warn(Color(0x1AF59E0B), Color(0x3DFCD34D), Color(0xFFFFD27A)),
  ok(Color(0x1A10B981), Color(0x3D6EE7B7), Color(0xFF8BE8C0)),
  sos(Color(0x1AF43F5E), Color(0x47FF8CA0), Color(0xFFFFA0B4));

  const GNoteKind(this.fill, this.border, this.icon);

  final Color fill;
  final Color border;
  final Color icon;

  /// Ogohlantirish yoki xato: paydo bo'lganda ekran o'quvchi o'qib beradi.
  bool get isAlert => this == warn || this == sos;
}

/// Izoh bloki: ikon + matn (ixtiyoriy pastda tugma yoki havola).
/// Ogohlantirish / xato turi jonli hudud — ekran o'quvchi darhol e'lon qiladi.
class GNote extends StatelessWidget {
  const GNote({
    super.key,
    required this.text,
    this.kind = GNoteKind.info,
    this.icon,
    this.action,
    this.showIcon = true,
  });

  final String text;
  final GNoteKind kind;
  final GIconData? icon;
  final Widget? action;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final note = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kind.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kind.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIcon) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: GIcon(
                icon ?? GIcons.info,
                size: 18,
                color: kind.icon,
                secondaryOpacity: .3,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: GText.note),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
    if (!kind.isAlert) return note;
    return Semantics(liveRegion: true, container: true, child: note);
  }
}

/// Yupqa progress chizig'i (6px).
class GProgressBar extends StatelessWidget {
  const GProgressBar({super.key, required this.value, this.semanticLabel});

  /// 0..1
  final double value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0x14FFFFFF)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clamped,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: GEffects.progressGradient,
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

enum GSegmentState { empty, ok, warn, now }

/// Bo'lakli progress (savollar: to'g'ri / xato / hozirgi).
class GSegments extends StatelessWidget {
  const GSegments({super.key, required this.states, this.semanticLabel});

  final List<GSegmentState> states;

  /// Masalan «4-savol, 10 tadan»: holat faqat rang bilan berilmasin.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < states.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: switch (states[i]) {
                    GSegmentState.empty => const Color(0x1AFFFFFF),
                    GSegmentState.ok => GColors.success,
                    GSegmentState.warn => GColors.warning,
                    GSegmentState.now => null,
                  },
                  gradient: states[i] == GSegmentState.now
                      ? GEffects.progressGradient
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dumaloq avatar: bosh harflar yoki rasm.
class GAvatar extends StatelessWidget {
  const GAvatar({
    super.key,
    required this.initials,
    this.hue = GHue.blue,
    this.size = 44,
    this.image,
  });

  final String initials;
  final GHue hue;
  final double size;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.base.withValues(alpha: .22),
        border: Border.all(color: hue.base.withValues(alpha: .4)),
        image: image != null
            ? DecorationImage(image: image!, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: image != null
          ? null
          : Text(
              initials,
              style: GText.display(size * .36).copyWith(color: hue.icon),
            ),
    );
  }
}

/// Yozishma pufagi: `mine` — bolaning o'z xabari (o'ngda, ko'k).
class GBubble extends StatelessWidget {
  const GBubble({super.key, required this.child, required this.mine});

  final Widget child;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(18);
    const tail = Radius.circular(6);
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: mine ? r : tail,
                bottomRight: mine ? tail : r,
              ),
              color: mine ? null : const Color(0x0FFFFFFF),
              gradient: mine
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x574F86FF), Color(0x382F5BEA)],
                    )
                  : null,
              border: Border.all(
                color: mine ? const Color(0x598CB4FF) : const Color(0x17FFFFFF),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: GText.onest(15, color: GColors.text, height: 1.45),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress halqasi (`.ring`): kulrang iz va gradient yoy (yuqoridan, soat
/// yo'nalishida). [colors] — yoy gradienti.
class GProgressRingPainter extends CustomPainter {
  const GProgressRingPainter(
    this.progress, {
    this.stroke = 8,
    this.colors = const [GColors.sky, Color(0xFF3B6BFF)],
  });

  final double progress;
  final double stroke;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2 + 3);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x14FFFFFF),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GProgressRingPainter old) =>
      old.progress != progress || old.stroke != stroke || old.colors != colors;
}
