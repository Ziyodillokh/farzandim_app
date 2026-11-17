// ─────────────────────────────────────────────────────────────────────
// school_kit — Maktab ichki sahifalari uchun umumiy dizayn bo'laklari
// ─────────────────────────────────────────────────────────────────────
//
// "Tungi shisha" uslubi: chuqur qora-ko'k fon, tutun rangli kartalar,
// yupqa yorug' chegara, ko'k aksent. Binafsha YO'Q. Matn — Poppins,
// sarlavha va raqamlar — Unbounded. Ikonlar — Solar.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar ════════════

abstract final class SK {
  static const bg = Color(0xFF00060A);
  static const card = Color(0xFF12181E);
  static const cardHi = Color(0xFF1A2129);
  static const border = Color(0x1FFFFFFF); // oq 12%
  static const hairline = Color(0x14FFFFFF); // oq 8%
  static const text = Colors.white;
  static const dim = Color(0x99FFFFFF); // oq 60%
  static const faint = Color(0x66FFFFFF); // oq 40%
  static const blue = Color(0xFF216BFF);
  static const sky = Color(0xFF5B9BFF);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFFF5A5D);
  static const teal = Color(0xFF2DD4BF);
  static const sheet = Color(0xFF0B1016);
}

TextStyle skDisplay(
  double size, {
  Color c = SK.text,
  FontWeight w = FontWeight.w600,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: -0.4,
  height: 1.25,
);

TextStyle skText(
  double size, {
  Color c = SK.text,
  FontWeight w = FontWeight.w400,
  double height = 1.5,
}) => GoogleFonts.poppins(
  fontSize: size,
  fontWeight: w,
  color: c,
  height: height,
);

// ════════════ Karta ════════════

/// Tutun rangli karta; [tint] — yuqori chap burchakdan yumshoq rang nuri,
/// [accent] — chap chetdagi ingichka chiziq (o'qilmagan / muhim).
class SkCard extends StatelessWidget {
  const SkCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.tint,
    this.accent,
    this.onTap,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Color? accent;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final tint = this.tint;
    final accent = this.accent;
    Widget body = Container(
      decoration: BoxDecoration(
        color: SK.card,
        borderRadius: br,
        border: Border.all(color: SK.border),
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint.withValues(alpha: 0.16), SK.card, SK.card],
                stops: const [0, 0.55, 1],
              ),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            if (accent != null)
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: br, child: body),
      );
    }
    return Semantics(button: onTap != null, label: semanticsLabel, child: body);
  }
}

/// Bo'lim sarlavhasi (katta harflar, xira).
class SkSectionLabel extends StatelessWidget {
  const SkSectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: skText(
                  12,
                  c: SK.dim,
                  w: FontWeight.w600,
                ).copyWith(letterSpacing: 1.2),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rangli doira ichida ikon.
class SkIconBubble extends StatelessWidget {
  const SkIconBubble({
    required this.icon,
    this.color = SK.sky,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

/// Ismdan bosh harflar bilan avatar (rangi roldan).
class SkAvatar extends StatelessWidget {
  const SkAvatar({
    required this.name,
    this.color = SK.sky,
    this.size = 48,
    super.key,
  });

  final String name;
  final Color color;
  final double size;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.55),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(
        initials(name),
        style: skDisplay(size * 0.32, w: FontWeight.w500),
      ),
    );
  }
}

/// Tanlanadigan pill (filtr, o'quvchi tanlovi).
class SkChip extends StatelessWidget {
  const SkChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final icon = this.icon;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? SK.blue : SK.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? SK.blue : SK.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(label, style: skText(13.5, w: FontWeight.w500)),
              if (count != null && count > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : SK.blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: skText(
                      11.5,
                      w: FontWeight.w700,
                      c: selected ? SK.blue : Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kichik rangli yorliq (holat, mavzu). [maxLines] — tor joyda matn
/// nechta qatorga o'ta oladi (odatda bitta).
class SkTag extends StatelessWidget {
  const SkTag({
    required this.label,
    this.color = SK.sky,
    this.icon,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final int maxLines;

  static const double _padX = 10;
  static const double _border = 1;
  static const double _iconSize = 13;
  static const double _iconGap = 5;

  TextStyle get _style => skText(12, c: color, w: FontWeight.w600, height: 1.3);

  /// Yorliq bir qatorga to'liq sig'ishi uchun kerak bo'lgan kenglik
  /// (joriy shrift kattaligi bilan).
  double naturalWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final text = painter.width;
    painter.dispose();
    final iconPart = icon == null ? 0 : _iconSize + _iconGap;
    return text + iconPart + 2 * (_padX + _border);
  }

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: color),
            const SizedBox(width: _iconGap),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: _style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Raqam + yorliq (kichik statistik kartacha).
class SkStat extends StatelessWidget {
  const SkStat({
    required this.value,
    required this.label,
    this.color = SK.text,
    this.icon,
    super.key,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: SK.cardHi.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SK.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skDisplay(18, c: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: skText(12, c: SK.dim, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Foiz halqasi (markazda matn). [segments] — rangli bo'laklar ulushi.
class SkRing extends StatelessWidget {
  const SkRing({
    required this.size,
    required this.segments,
    required this.center,
    this.stroke = 12,
    super.key,
  });

  final double size;
  final List<(double, Color)> segments;
  final Widget center;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(segments: segments, stroke: stroke),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.segments, required this.stroke});

  final List<(double, Color)> segments;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    var start = -math.pi / 2;
    const gap = 0.035;
    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = math.pi * 2 * fraction.clamp(0, 1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      final visible = sweep > gap * 2 ? sweep - gap : sweep;
      canvas.drawArc(arcRect, start + gap / 2, visible, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.segments != segments || old.stroke != stroke;
}

/// Gorizontal taqqoslash chizig'i (masalan, "Farzandingiz" vs "Sinf").
class SkBar extends StatelessWidget {
  const SkBar({
    required this.fraction,
    this.color = SK.blue,
    this.height = 8,
    super.key,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.07)),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.7), color],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
