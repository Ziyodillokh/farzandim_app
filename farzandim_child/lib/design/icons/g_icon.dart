// Phosphor Duotone ikonlari: ikki qatlam (orqa "fill" qatlami shaffof + asosiy chiziq).
//
// Glyflar `g_icons.g.dart`da SVG path ko'rinishida (256 to'r). Path faqat
// M/L/Q/H/V/Z (absolyut) buyruqlaridan iborat — shuning uchun kichik o'z
// parserimiz yetadi va har bir glyf bir marta parse qilinib keshlanadi.

import 'package:flutter/widgets.dart';

part 'g_icons.g.dart';

/// Bitta duotone glyf: asosiy (`primary`) va orqa qatlam (`secondary`) path'lari.
@immutable
class GIconData {
  const GIconData(this.primary, this.secondary);

  final String primary;
  final String secondary;
}

/// Duotone ikon. `secondaryOpacity` 0 bo'lsa faqat asosiy chiziq chiziladi.
class GIcon extends StatelessWidget {
  const GIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.secondaryOpacity = .32,
    this.semanticLabel,
  });

  final GIconData icon;
  final double size;

  /// Berilmasa atrofdagi `IconTheme` rangi olinadi.
  final Color? color;
  final double secondaryOpacity;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? const Color(0xFFEDF2FF);
    final painted = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GIconPainter(icon, resolved, secondaryOpacity),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: painted);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: painted),
    );
  }
}

class _GIconPainter extends CustomPainter {
  _GIconPainter(this.icon, this.color, this.secondaryOpacity);

  final GIconData icon;
  final Color color;
  final double secondaryOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _grid, size.height / _grid);
    if (secondaryOpacity > 0) {
      canvas.drawPath(
        GIconPaths.parse(icon.secondary),
        Paint()..color = color.withValues(alpha: color.a * secondaryOpacity),
      );
    }
    canvas.drawPath(GIconPaths.parse(icon.primary), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GIconPainter old) =>
      old.icon != icon ||
      old.color != color ||
      old.secondaryOpacity != secondaryOpacity;
}

const _grid = 256.0;

/// SVG path parser (M, L, Q, H, V, Z — absolyut) va kesh.
abstract final class GIconPaths {
  static final _cache = <String, Path>{};

  static Path parse(String data) =>
      _cache.putIfAbsent(data, () => _parse(data));

  static final _token = RegExp(r'[A-Za-z]|-?\d*\.?\d+');

  static Path _parse(String data) {
    final path = Path()..fillType = PathFillType.nonZero;
    final tokens = _token.allMatches(data).map((m) => m.group(0)!).toList();
    var i = 0;
    var command = 'M';
    var x = 0.0;
    var y = 0.0;
    double next() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      final token = tokens[i];
      if (_isCommand(token)) {
        command = token;
        i++;
        if (command == 'Z') {
          path.close();
          continue;
        }
      }
      switch (command) {
        case 'M':
          x = next();
          y = next();
          path.moveTo(x, y);
          // SVG qoidasi: M dan keyingi juftliklar L hisoblanadi.
          command = 'L';
        case 'L':
          x = next();
          y = next();
          path.lineTo(x, y);
        case 'H':
          x = next();
          path.lineTo(x, y);
        case 'V':
          y = next();
          path.lineTo(x, y);
        case 'Q':
          final cx = next();
          final cy = next();
          x = next();
          y = next();
          path.quadraticBezierTo(cx, cy, x, y);
        default:
          throw FormatException('Unsupported path command "$command"', data);
      }
    }
    return path;
  }

  static bool _isCommand(String token) =>
      token.length == 1 && RegExp('[A-Za-z]').hasMatch(token);
}
