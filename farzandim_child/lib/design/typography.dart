// Growth v5 matn uslublari: Unbounded (sarlavha va raqamlar) + Onest (matn).
//
// Ikkala shrift ham assets/google_fonts/ ichida bundle qilingan
// (allowRuntimeFetching = false) — kirill va oʻ/gʻ (U+02BB) belgilari bor.

import 'package:farzandim_child/design/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

const _tabular = [FontFeature.tabularFigures()];

TextStyle _onest(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
}) {
  return GoogleFonts.onest(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontFeatures: _tabular,
  );
}

TextStyle _unbounded(
  double size, {
  FontWeight weight = FontWeight.w600,
  double height = 1.2,
}) {
  return GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: weight,
    color: GColors.text,
    height: height,
    letterSpacing: -.02 * size,
    fontFeatures: _tabular,
  );
}

/// Kanvasdagi matn sinflari (`.h1`, `.h3`, `.body`, `.cap` va h.k.).
abstract final class GText {
  /// Ekran sarlavhasi (`.h1`, 24).
  static final TextStyle h1 = _unbounded(24);

  /// Bo'lim sarlavhasi (`.h2`, 20).
  static final TextStyle h2 = _unbounded(20, height: 1.25);

  /// Karta sarlavhasi (`.h3`, 17 bold).
  static final TextStyle h3 = _onest(
    17,
    FontWeight.w700,
    GColors.text,
    height: 1.3,
  );

  /// Yuqori panel sarlavhasi (`.top-t h1`, 19).
  static final TextStyle topTitle = _unbounded(19);

  /// Yuqori panel izohi (`.top-t p`).
  static final TextStyle topSub = _onest(
    12.5,
    FontWeight.w500,
    GColors.textMuted,
  );

  /// Asosiy matn (`.body`, 15).
  static final TextStyle body = _onest(
    15,
    FontWeight.w500,
    GColors.textBody,
    height: 1.5,
  );

  /// Qator sarlavhasi (`.li-t b`, 15 bold).
  static final TextStyle itemTitle = _onest(
    15,
    FontWeight.w700,
    GColors.text,
    height: 1.3,
  );

  /// Kichik izoh (`.cap`, `.hint`, `.li-t small`).
  static final TextStyle caption = _onest(
    12.5,
    FontWeight.w500,
    GColors.textMuted,
    height: 1.45,
  );

  /// Bo'lim yorlig'i (`.lb`, `.sec-h h2`): 11, katta harf, keng oraliq.
  static final TextStyle label = _onest(
    11,
    FontWeight.w700,
    GColors.textMuted,
  ).copyWith(letterSpacing: 11 * .16);

  /// Maydon yorlig'i (`.fl`).
  static final TextStyle fieldLabel = _onest(
    13,
    FontWeight.w600,
    GColors.textLabel,
  );

  /// Xato matni (`.ferr`).
  static final TextStyle error = _onest(13, FontWeight.w600, GColors.errorText);

  /// Eslatma matni (`.note`).
  static final TextStyle note = _onest(
    13.5,
    FontWeight.w500,
    GColors.textBody,
    height: 1.45,
  );

  /// Havola (`.link`, `.sec-h .act`).
  static final TextStyle link = _onest(14, FontWeight.w600, GColors.link);

  /// Chip matni (`.chip`).
  static final TextStyle chip = _onest(12, FontWeight.w600, GColors.text);

  /// Yozishma va metadata (`.meta`).
  static final TextStyle meta = _onest(
    11.5,
    FontWeight.w500,
    GColors.textFaint,
  );

  /// Tugma matni: katta (`.btn-lg` 17), o'rta (`.btn-md` 15), ikkinchi (`.btn2` 15/600).
  static final TextStyle buttonLg = _onest(17, FontWeight.w700, GColors.white);
  static final TextStyle buttonMd = _onest(15, FontWeight.w700, GColors.white);
  static final TextStyle button2 = _onest(15, FontWeight.w600, GColors.text);

  /// Pastki menyu yorlig'i.
  static final TextStyle tab = _onest(
    11.5,
    FontWeight.w600,
    GColors.textFaint,
  ).copyWith(letterSpacing: 11.5 * .01);

  /// Raqamlar uchun Unbounded (`.d`): o'lcham beriladi.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
  }) => _cache.putIfAbsent(
    'd|$size|${weight.value}',
    () => _unbounded(size, weight: weight),
  );

  /// Har qanday o'lchamdagi Onest.
  static TextStyle onest(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = GColors.text,
    double? height,
  }) => _cache.putIfAbsent(
    'o|$size|${weight.value}|${color.toARGB32()}|$height',
    () => _onest(size, weight, color, height: height),
  );

  /// `build` ichida har chaqiruvda GoogleFonts'dan yangi uslub yaratilmasin.
  static final _cache = <String, TextStyle>{};
}
