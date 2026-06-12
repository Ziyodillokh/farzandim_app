// Loyihaning 5 ta asosiy matn stili — widget'larda TextStyle qo'lda
// yozilmaydi, rang kerak bo'lsa `.copyWith()` qilinadi. Shrift: Inter
// (google_fonts birinchi ishga tushishda yuklab keshlaydi).

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  /// Eng katta sarlavha — 32sp, w700. Ekranda 1-2 marta ishlatiladi
  /// (Welcome sarlavhasi, dashboard salomlashuvi).
  static TextStyle get headlineXL => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        // Katta sarlavhada zich tracking va line-height chiroyli turadi.
        letterSpacing: -0.6,
        height: 1.12,
      );

  /// Bo'lim sarlavhalari — 24sp, w600 (AppBar title, dialog
  /// va bottom sheet sarlavhalari).
  static TextStyle get headlineL => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.18,
      );

  /// Asosiy matn — 17sp, w400. Eng ko'p ishlatiladigan stil
  /// (paragraflar, ListTile matni, TextField).
  static TextStyle get bodyM => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
        letterSpacing: -0.1,
      );

  /// Kichik tafsilotlar — 15sp, w400 (subtitle, vaqt yorlig'i, hint).
  /// Odatda `.copyWith(color: AppColors.textSecondary)` bilan ishlatiladi.
  static TextStyle get bodyS => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  /// Eng kichik matn — 12sp, w500 (chip yorlig'i, badge, status yozuvi).
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        // Kichik yorliq yengil ochiq tracking bilan tozaroq o'qiladi.
        letterSpacing: 0.2,
        height: 1.2,
      );
}
