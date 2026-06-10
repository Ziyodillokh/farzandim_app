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

/// Farzandim ilovasining theme'i — **light va dark** (theme-aware).
///
/// `AppColors.brightness` ni `app.dart` theme provider'dan o'rnatadi, keyin
/// `AppTheme.build()` joriy yorqinlikka mos `ThemeData` quradi. Bitta
/// build — `AppColors` getterlari rangni o'zi tanlaydi (light/dark).
class AppTheme {
  AppTheme._();

  /// Joriy `AppColors.brightness` ga mos ThemeData. `app.dart` brightness'ni
  /// o'rnatgandan keyin chaqiriladi.
  static ThemeData build() {
    final isDark = AppColors.isDark;
    return ThemeData(
      brightness: AppColors.brightness,

      // ────── 1. RANG TIZIMI (ColorScheme) ──────
      colorScheme:
          (isDark ? const ColorScheme.dark() : const ColorScheme.light())
              .copyWith(
                primary:
                    AppColors.primary, // brand yashil (#235347 / dark #2F6B5C)
                onPrimary: AppColors.onPrimary, // primary ustida DOIM oq matn
                secondary: AppColors.secondary,
                onSecondary: AppColors.onPrimary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
                surfaceContainerHighest: AppColors.surfaceVariant,
                error: AppColors.error,
                onError: Colors.white,
                outline: AppColors.border,
              ),

      // Scaffold fon — solid theme baza rangi (AVVAL transparent edi).
      // GradientBackground ustidan chiziladi, shuning uchun ko'rinish
      // o'zgarmaydi; ammo overscroll/pull-to-refresh paytida content
      // ortidan OQ oyna foni ko'rinib qolmaydi (theme rangi ko'rinadi).
      scaffoldBackgroundColor: AppColors.background,

      // Premium soya rangi — Material elevation'lar uchun. Light'da sof qora
      // emas, salqin navy-tus (yumshoq, qimmatbaho); dark'da chuqur qora.
      shadowColor: isDark ? Colors.black : const Color(0xFF0B2B26),

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
        // Status bar ikonlari: dark mode'da oq, light mode'da qora.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
          foregroundColor: AppColors.onPrimary, // lime green ustida DOIM to'q
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDimensions.radiusPill),
            ),
          ),
          textStyle: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
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
          side: BorderSide(color: AppColors.textPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDimensions.radiusPill),
            ),
          ),
          textStyle: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w500),
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
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTextStyles.bodyM.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTextStyles.bodyS.copyWith(
          color: AppColors.textSecondary,
        ),
      ),

      // ────── 7. IKONKALAR ──────
      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: AppDimensions.iconM,
      ),

      // ────── 8. AJRATUVCHI CHIZIQ (Divider) ──────
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
