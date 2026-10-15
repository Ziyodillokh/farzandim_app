// Fan ikonkasi — ko'k yumaloq kvadrat ichida fan belgisi
// (Matematika: √x, Ingliz tili: Aa, Ona tili: kitoblar, qolganlari Solar).

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

const _squareColor = Color(0xFF1356AA);
const _glyphColor = Color(0xFFD3E6FF);

/// √x — ildiz chizig'i x ustigacha cho'zilgan.
const _sqrtXSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g fill="none" stroke="#FFFFFF" stroke-width="2.3" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M1.6 13.2L4.2 12.2L7.2 20L11.4 4H22.4"/>'
    '<path d="M13.4 9.6L20.4 18.6M20.4 9.6L13.4 18.6"/></g></svg>';

class SubjectIcon extends StatelessWidget {
  const SubjectIcon({super.key, required this.subject, this.size = 35});

  final Subject subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _squareColor,
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: const [
          BoxShadow(color: Color(0x401356AA), blurRadius: 8, spreadRadius: -2),
        ],
      ),
      child: _glyph(),
    );
  }

  Widget _glyph() {
    final g = size * 0.6;
    switch (subject) {
      case Subject.math:
        return SvgPicture.string(
          _sqrtXSvg,
          width: g,
          height: g,
          colorFilter: const ColorFilter.mode(_glyphColor, BlendMode.srcIn),
        );
      case Subject.english:
        return Text(
          'Aa',
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.47,
            fontWeight: FontWeight.w800,
            color: _glyphColor,
            height: 1,
            letterSpacing: -0.3,
          ),
        );
      case Subject.native:
        return CustomPaint(
          size: Size(size * 0.46, size * 0.5),
          painter: const _BookStackPainter(),
        );
      case Subject.history:
        return Icon(SolarIconsBold.history, size: g, color: _glyphColor);
      case Subject.biology:
        return Icon(SolarIconsBold.leaf, size: g, color: _glyphColor);
      case Subject.geography:
        return Icon(SolarIconsBold.globus, size: g, color: _glyphColor);
      case Subject.physics:
        return Icon(SolarIconsBold.atom, size: g, color: _glyphColor);
      case Subject.chemistry:
        return Icon(SolarIconsBold.testTube, size: g, color: _glyphColor);
      case Subject.informatics:
        return Icon(SolarIconsBold.monitor, size: g, color: _glyphColor);
      case Subject.russian:
        // Plus Jakarta'da kirill yo'q — Montserrat (bundle, 800).
        return Text(
          'Яя',
          style: GoogleFonts.montserrat(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: _glyphColor,
            height: 1,
          ),
        );
    }
  }
}

/// Ona tili — uch qavat kitob (maketdagi "E" shaklli belgi).
class _BookStackPainter extends CustomPainter {
  const _BookStackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = Radius.circular(h * 0.2);
    final body = Paint()..color = _glyphColor;
    canvas.drawRRect(RRect.fromLTRBR(0, 0, w, h, r), body);

    // Ikki gorizontal "sahifa" tirqishi — o'ngdan ochiq, kitoblar qatlami.
    final slot = Paint()..color = _squareColor;
    final slotH = h * 0.14;
    for (final top in [h * 0.25, h * 0.61]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          w * 0.22,
          top,
          w * 0.82,
          top + slotH,
          Radius.circular(slotH / 2),
        ),
        slot,
      );
      // Tirqish o'ng chetdagi kesik bilan tutashadi.
      canvas.drawRect(
        Rect.fromLTRB(
          w * 0.82 - slotH / 2,
          top + slotH * 0.32,
          w,
          top + slotH * 0.68,
        ),
        slot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
