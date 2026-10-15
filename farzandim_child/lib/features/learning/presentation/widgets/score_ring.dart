// Natija halqasi — ko'k gradientli yoy, yumshoq nur va iz (Rivojlanish
// hero kartasi va test natijasi sahifasi uchun umumiy).

import 'dart:math' as math;

import 'package:flutter/material.dart';

const _ringStart = Color(0xFF1A72F2);
const _ringEnd = Color(0xFF4AA6FF);
const _ringTrack = Color(0xFF0E2238);

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.percent,
    required this.size,
    this.stroke = 10.5,
    this.child,
  });

  /// 0–100.
  final int percent;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: percent.clamp(0, 100) / 100,
          stroke: stroke,
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.stroke});

  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _ringTrack,
    );
    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress;
    const start = -math.pi / 2;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: sweep,
      colors: const [_ringStart, _ringEnd],
      transform: const GradientRotation(start),
    );
    // Yumshoq nur.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _ringStart.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.stroke != stroke;
}
