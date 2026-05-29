// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — TEMA (ThemeData)
// ─────────────────────────────────────────────────────────────────────
//
// Bu fayl 3 ta xom faylni (`app_colors`, `app_text_styles`,
// `app_dimensions`) bir joyga yig'ib, Flutter'ga **`ThemeData`** sifatida
// uzatadi.
//
// `MaterialApp(theme: AppTheme.dark)` deganimizdan keyin:
//   - Scaffold avtomatik qora fonda
//   - Text avtomatik Inter shrifti, oq rangda
//   - ElevatedButton avtomatik lime green pill
//   - TextField avtomatik bizning input dizaynda
//   - va h.k.
//
// Ya'ni har widget'da uslubni qaytadan yozish kerak emas — global
// "default" sozlamalar shu yerda.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Farzandim ilovasining theme'lari.
///
/// Hozircha **faqat dark theme** bor. Light mode keyingi versiyalarga
/// qoldirilgan (CLAUDE.md: "Theme: DARK MODE (default)").
class AppTheme {
  AppTheme._();

  /// Dark theme — ilovaning yagona theme'i.
  ///
  /// `MaterialApp(theme: AppTheme.dark)` deb chaqiriladi.
  static ThemeData get dark {
    return ThemeData(
      // Material 3 yangi Flutter'da default — alohida yozish shart emas.
      brightness: Brightness.dark,

      // ────── 1. RANG TIZIMI (ColorScheme) ──────
      //
      // Material widget'lari ColorScheme'ga qarab ranglarni tanlaydi.
      // Masalan, ElevatedButton avtomatik `primary` fon va `onPrimary`
      // matn rangini oladi.
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary, // lime green (#C5F562)
        onPrimary: AppColors.background, // lime green ustida qora matn
        secondary: AppColors.secondary, // turkuaz (#3DBFB4)
        onSecondary: AppColors.background,
        surface: AppColors.surface, // Card, Dialog, BottomSheet fon
        // onSurface defaulti `Colors.white` — `textPrimary` ham aynan oq,
        // shuning uchun yozish shart emas.
        surfaceContainerHighest: AppColors.surfaceVariant,
        error: AppColors.error,
        onError: AppColors.textPrimary,
        outline: AppColors.border,
      ),

      // Scaffold fon — **transparent**. Har ekran o'z body'sini
      // `GradientBackground` widget'i bilan o'rab oladi (PDF dizayni
      // bo'yicha gradient fon).
      //
      // ⚠️ Eslatma: agar yangi ekran `GradientBackground` ichida emas bo'lsa,
      // foni transparent ko'rinadi (web'da oq). Har Scaffold'ni tekshiring.
      scaffoldBackgroundColor: Colors.transparent,

      // ────── 2. SHRIFT TIZIMI (TextTheme) ──────
      //
      // 1) `GoogleFonts.interTextTheme()` — barcha 13 ta TextTheme
      //    yo'liga Inter shriftini qo'yadi.
      // 2) `.apply()` — ularning hammasiga oq matn rangini qo'shadi.
      // 3) `.copyWith()` — eng muhim role'larni o'zimizning aniq
      //    AppTextStyles bilan almashtiradi.
      //
      // Natija: `Text('hello')` deb yozsangiz — Inter, oq, 16sp.
      textTheme: GoogleFonts.interTextTheme()
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            displayLarge: AppTextStyles.headlineXL,
            headlineLarge: AppTextStyles.headlineL,
            headlineMedium: AppTextStyles.headlineL,
            titleLarge: AppTextStyles.headlineL,
            bodyLarge: AppTextStyles.bodyM,
            // bodyMedium = default `Text(...)` widget stili.
            bodyMedium: AppTextStyles.bodyM,
            bodySmall: AppTextStyles.bodyS,
            labelLarge: AppTextStyles.label,
          ),

      // ────── 3. APPBAR ──────
      //
      // Sarlavha bar'ning sukut bo'yicha ko'rinishi.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0, // tag'imdagi soya yo'q (flat dizayn)
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineL,
        // Status bar (tepadagi vaqt, batareya): oq ikonkalar
        // (qora fonda yaxshi ko'rinadi).
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // ────── 4. ELEVATEDBUTTON (PrimaryButton stilining bazasi) ──────
      //
      // Lime green pill, qora matn, 56dp baland.
      // Keyinchalik `PrimaryButton` widget'i `ElevatedButton`'ni
      // o'rab oladi va bu stilni meros qilib oladi.
      // Eslatma: bu solid lime green ElevatedButton. Loyihada asosan
      // `PrimaryButton` widget'idan foydalanamiz
      // (`lib/shared/widgets/primary_button.dart`) — u bir xil ko'rinishda
      // lekin to'liq kenglikda va aniq disabled state bilan.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background, // lime green ustida qora
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppDimensions.radiusPill)),
          ),
          textStyle: AppTextStyles.bodyM.copyWith(
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // ────── 5. OUTLINEDBUTTON (SecondaryButton bazasi) ──────
      //
      // Shaffof fon, oq border, oq matn, 56dp baland.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          side: const BorderSide(color: AppColors.textPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppDimensions.radiusPill)),
          ),
          textStyle: AppTextStyles.bodyM.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ────── 6. TEXTFIELD ──────
      //
      // To'ldirilgan (filled) input field, yumshoq burchakli, fokuslanganda
      // lime green chegarali. Yangi widget yozish kerak emas — `TextField`
      // o'zi shu stilni avtomatik oladi.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTextStyles.bodyM.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: AppTextStyles.bodyS.copyWith(
          color: AppColors.textSecondary,
        ),
      ),

      // ────── 7. IKONKALAR ──────
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: AppDimensions.iconM,
      ),

      // ────── 8. AJRATUVCHI CHIZIQ (Divider) ──────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
