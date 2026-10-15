// ─────────────────────────────────────────────────────────────────────
// Bosh sahifa (Growth "Asosiy") — dizayn tokenlari
// ─────────────────────────────────────────────────────────────────────
//
// Manba: Growth yangi konsepsiyasi dashboard maketi (iPhone 15 Pro,
// 393×852 pt). Ranglar va o'lchamlar maketdan piksel bo'yicha olingan.
//
// Shriftlar (ikkalasi ham assets/google_fonts'da BUNDLE — faqat shu
// og'irliklar mavjud, boshqasi ishlatilsa google_fonts istisno tashlaydi):
//   • Montserrat 700/800 — sarlavhalar va katta raqamlar
//   • Plus Jakarta Sans 400–800 — qolgan matnlar

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bosh sahifa ranglari.
abstract final class HomeColors {
  static const bg = Color(0xFF03060A);

  /// Neytral karta (stat, natijalar, kutubxona).
  static const card = Color(0xFF0C1116);
  static const cardBorder = Color(0x1FFFFFFF);

  /// Karta ichidagi plitka (natijalar).
  static const tile = Color(0xFF111B26);
  static const tileBorder = Color(0x14FFFFFF);

  /// Header tugmalari foni.
  static const iconButton = Color(0xFF0F151B);

  /// "Bugungi testlar" kartasi — ko'k gradient.
  static const testsTop = Color(0xFF0A3360);
  static const testsBottom = Color(0xFF042142);
  static const testsBorder = Color(0xFF13467F);
  static const testsTile = Color(0x66021630);
  static const testsTileBorder = Color(0x1A8FB8FF);
  static const calendarButton = Color(0xFF143D70);
  static const subjectSquare = Color(0xFF1356AA);
  static const subjectGlyph = Color(0xFFD3E6FF);

  /// Asosiy CTA ("Boshlash"), DON belgisi.
  static const primary = Color(0xFF1B6FDD);
  static const donBadge = Color(0xFF0B68F2);

  static const text = Colors.white;

  /// Ikkilamchi matn — och ko'k-kulrang.
  static const textDim = Color(0xFFA9BFD8);
  static const chevron = Color(0xFFB0BCD0);

  // Aksentlar.
  static const amber = Color(0xFFFFA51A);
  static const blue = Color(0xFF4DA4FE);
  static const green = Color(0xFF14D68C);
  static const orange = Color(0xFFF98F18);
  static const ring = Color(0xFF3594FA);
  static const ringTrack = Color(0xFF1A2A3A);
}

/// Sarlavha / katta raqam — Montserrat (700 yoki 800).
TextStyle homeDisplay(
  double size, {
  FontWeight weight = FontWeight.w800,
  Color color = HomeColors.text,
  double letterSpacing = 0,
  double height = 1.15,
}) => GoogleFonts.montserrat(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// Oddiy matn — Plus Jakarta Sans (400–800).
TextStyle homeText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = HomeColors.text,
  double letterSpacing = 0,
  double height = 1.3,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// Neytral karta bezagi (stat / natijalar / kutubxona).
BoxDecoration homeCardDecoration({double radius = 22}) => BoxDecoration(
  color: HomeColors.card,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: HomeColors.cardBorder),
);

/// Sahifa sarlavhasi tepasidagi masofa — status bar ostida.
///
/// iOS'da xavfsiz zona allaqachon status bar ostidagi bo'shliqni o'z ichiga
/// oladi (maketdagidek); Android'da status bar balandligi faqat ikonlar
/// qatori — sarlavha unga yopishib qolmasligi uchun qo'shimcha bo'shliq.
double growthTopInset(BuildContext context) {
  final top = MediaQuery.paddingOf(context).top;
  final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  return isIOS ? top - 2 : top + 8;
}

/// Bir qatorli matn — joy yetmasa kesilmaydi, sig'guncha kichrayadi.
class FitText extends StatelessWidget {
  const FitText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}
