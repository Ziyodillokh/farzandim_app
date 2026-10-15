// Fan kartalari uslubi — rang, ikon kvadrati, pastki nur (Testlar maketi).
// Maketda yo'q fanlar (fizika, kimyo…) uchun ham shu uslubda rang/ikon.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ochiq kitob (Ilmiy-ommabop).
const _openBookSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="#FFFFFF">'
    '<path d="M11 6.2C9 4.9 6.6 4.2 4 4C3.1 3.9 2.4 4.6 2.4 5.5V16.6C2.4 17.4 3 '
    '18 3.8 18.1C6.4 18.3 8.8 19.1 11 20.4Z"/>'
    '<path d="M13 6.2C15 4.9 17.4 4.2 20 4C20.9 3.9 21.6 4.6 21.6 5.5V16.6C21.6 '
    '17.4 21 18 20.2 18.1C17.6 18.3 15.2 19.1 13 20.4Z"/></g></svg>';

/// √x (Matematika).
const _sqrtXSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g fill="none" stroke="#FFFFFF" stroke-width="2.4" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M1.6 13.2L4.2 12.2L7.2 20L11.4 4H22.4"/>'
    '<path d="M13.4 9.6L20.4 18.6M20.4 9.6L13.4 18.6"/></g></svg>';

/// Globus — to'ldirilgan doira + qorong'i chiziqlar (Ingliz tili).
String _globeSvg(String fill, String line) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<circle cx="12" cy="12" r="9.8" fill="$fill"/>'
    '<g fill="none" stroke="$line" stroke-width="1.5">'
    '<ellipse cx="12" cy="12" rx="4" ry="9.6"/>'
    '<path d="M2.4 12H21.6M5.6 7.4H18.4M5.6 16.6H18.4"/></g></svg>';

/// Barg — to'ldirilgan + qorong'i tomir (Biologiya).
String _leafSvg(String fill, String line) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path fill="$fill" d="M21 3C11.8 3.1 4.8 7.5 4.8 14.4C4.8 16.4 5.4 18 6.4 '
    '19.2C7.6 20.4 9.2 21 11.2 21C17.6 21 21.3 14.9 21 3Z"/>'
    '<path fill="none" stroke="$line" stroke-width="1.7" stroke-linecap="round" '
    'd="M3 22C6.6 16.8 10.8 12.6 16 9.2"/></svg>';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Bir fanning vizual uslubi.
class SubjectStyle {
  const SubjectStyle({required this.color, required this.icon});

  /// Asosiy (yorqin) rang — ikon.
  final Color color;

  /// Ikon chizuvchi: (o'lcham, kvadrat foni rangi) → vidjet.
  final Widget Function(double size, Color background) icon;

  /// Ikon kvadrati foni — rang kartaning to'q foniga ~22% aralashgan.
  Color get squareColor =>
      Color.alphaBlend(color.withValues(alpha: 0.22), const Color(0xFF141823));

  /// Karta pastidagi rangli nur.
  Color get glowColor => color.withValues(alpha: 0.4);
}

Widget _svg(String svg, double size, {Color? tint}) => SvgPicture.string(
  svg,
  width: size,
  height: size,
  colorFilter: tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
);

SubjectStyle _iconStyle(Color color, IconData icon) => SubjectStyle(
  color: color,
  icon: (size, _) => Icon(icon, size: size, color: color),
);

/// Fan kaliti (`testSubjectKey`) → uslub.
SubjectStyle subjectStyleFor(String key) {
  switch (key) {
    case 'ilmiy':
      const c = Color(0xFFA484FF);
      return SubjectStyle(
        color: c,
        icon: (size, _) => _svg(_openBookSvg, size, tint: c),
      );
    case 'matematika':
      const c = Color(0xFF2EE89A);
      return SubjectStyle(
        color: c,
        icon: (size, _) => _svg(_sqrtXSvg, size * 0.92, tint: c),
      );
    case 'ingliz':
      const c = Color(0xFF45AEFF);
      return SubjectStyle(
        color: c,
        icon: (size, bg) => _svg(_globeSvg(_hex(c), _hex(bg)), size),
      );
    case 'tarix':
      return _iconStyle(const Color(0xFFFF6464), SolarIconsBold.map);
    case 'geografiya':
      return _iconStyle(const Color(0xFF16DDF2), SolarIconsBold.gps);
    case 'biologiya':
      const c = Color(0xFFFFCC1F);
      return SubjectStyle(
        color: c,
        icon: (size, bg) => _svg(_leafSvg(_hex(c), _hex(bg)), size),
      );
    case 'ona_tili':
      return _iconStyle(
        const Color(0xFFFF7EB6),
        SolarIconsBold.bookMinimalistic,
      );
    case 'fizika':
      return _iconStyle(const Color(0xFF8C9BFF), SolarIconsBold.atom);
    case 'kimyo':
      return _iconStyle(const Color(0xFFFFA048), SolarIconsBold.testTube);
    case 'it':
      return _iconStyle(const Color(0xFF34D3A0), SolarIconsBold.monitor);
    default:
      return _iconStyle(const Color(0xFF9DB0CC), SolarIconsBold.cupStar);
  }
}
