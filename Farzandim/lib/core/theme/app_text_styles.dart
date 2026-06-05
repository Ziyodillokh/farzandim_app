// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — SHRIFT STILLARI (Typography)
// ─────────────────────────────────────────────────────────────────────
//
// Loyihada 5 ta asosiy matn stili ishlatamiz. Hech bir widget'da
// `TextStyle(fontSize: 16, ...)` to'g'ridan-to'g'ri yozilmaydi —
// faqat shu yerdan olib ishlatamiz:
//
//   Text('Salom', style: AppTextStyles.headlineXL)
//
// Rangni boshqacha qilish kerak bo'lsa, `.copyWith()` ishlatamiz:
//
//   Text('hint', style: AppTextStyles.bodyS.copyWith(
//     color: AppColors.textSecondary,
//   ))
//
// Shrift: Inter (Google Fonts). Internet'dan birinchi ishga tushishda
// avtomatik yuklanadi va keshlanadi (`google_fonts` paketi qiladi).

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Farzandim ilovasining shrift stillari.
///
/// Bu klassdan obyekt yaratilmaydi — faqat static maydonlardan
/// foydalaniladi: `AppTextStyles.headlineXL`, `AppTextStyles.bodyM`, ...
class AppTextStyles {
  AppTextStyles._();

  /// **Headline XL** — 28sp, Bold (w700).
  ///
  /// Ekrandagi eng katta matn. Bir ekranda 1-2 marta ishlatiladi.
  ///
  /// Qayerda: Welcome ekranidagi "Farzandim" sarlavhasi,
  /// dashboard'dagi "Salom, Aliyev!" salomlashish.
  static TextStyle get headlineXL => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// **Headline L** — 22sp, Semibold (w600).
  ///
  /// Bo'lim sarlavhalari — ekran ichidagi bo'limlarni ajratuvchi.
  ///
  /// Qayerda: "Mening farzandlarim", "Bugungi statistika",
  /// Dialog va BottomSheet sarlavhalari, AppBar title.
  static TextStyle get headlineL => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// **Body M** — 16sp, Regular (w400).
  ///
  /// Asosiy matn — eng ko'p ishlatiladigan stil.
  ///
  /// Qayerda: paragrafalar, ListTile asosiy matni, tugma matni
  /// (PrimaryButton ichida — `label` o'rniga `bodyM` ham bo'ladi),
  /// TextField ichidagi terilayotgan matn.
  static TextStyle get bodyM => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  /// **Body S** — 14sp, Regular (w400).
  ///
  /// Kichik tafsilotlar — asosiy matnga qo'shimcha.
  ///
  /// Qayerda: ListTile `subtitle`, "5 daqiqa oldin" vaqt yorlig'i,
  /// description matni, hint va helper text TextField ostida.
  ///
  /// Eslatma: bu joyda odatda `textSecondary` rangi qo'llaniladi —
  /// `.copyWith(color: AppColors.textSecondary)` qiling.
  static TextStyle get bodyS => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  /// **Label** — 12sp, Medium (w500).
  ///
  /// Eng kichik matn — yorliqlar, tag'lar, status yozuvlari.
  ///
  /// Qayerda: chip ichidagi yorliq ("Online"), badge raqamlari,
  /// kichik tugma matni, kategoriya nomlari.
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );
}
