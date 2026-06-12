// app_colors/app_text_styles/app_dimensions'ni bitta ThemeData'ga yig'adi —
// global default'lar shu yerda, har widget'da uslubni qaytadan yozish
// kerak emas.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ilova theme'i (light va dark). `app.dart` avval `AppColors.brightness`
/// ni o'rnatadi, keyin `build()` shunga mos `ThemeData` quradi —
/// `AppColors` getterlari rangni o'zi tanlaydi.
class AppTheme {
  AppTheme._();

  /// Joriy `AppColors.brightness` ga mos ThemeData quradi.
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
                onPrimary: AppColors.onPrimary, // primary ustida doim oq matn
                secondary: AppColors.secondary,
                onSecondary: AppColors.onPrimary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
                surfaceContainerHighest: AppColors.surfaceVariant,
                error: AppColors.error,
                onError: Colors.white,
                outline: AppColors.border,
              ),

      // Scaffold fon — solid theme baza rangi (avval transparent edi).
      // GradientBackground ustidan chiziladi, ko'rinish o'zgarmaydi; ammo
      // overscroll paytida content ortidan oq oyna foni ko'rinib qolmaydi.
      scaffoldBackgroundColor: AppColors.background,

      // Material elevation soyalari uchun rang. Light'da sof qora emas,
      // salqin navy-tus; dark'da chuqur qora.
      shadowColor: isDark ? Colors.black : const Color(0xFF0B2B26),

      // ────── 2. SHRIFT TIZIMI (TextTheme) ──────
      //
      // interTextTheme barcha yo'llarga Inter qo'yadi, .apply() matn
      // rangini beradi, .copyWith() asosiy role'larni AppTextStyles bilan
      // almashtiradi. Natijada oddiy Text() ham to'g'ri stil oladi.
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
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0, // flat dizayn — ostida soya yo'q
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineL,
        // Status bar ikonlari: dark mode'da oq, light mode'da qora.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // ────── 4. ELEVATEDBUTTON (PrimaryButton stilining bazasi) ──────
      //
      // Brand yashil pill, oq matn. Loyihada asosan `PrimaryButton`
      // widget'idan foydalanamiz — u shu stilni meros qiladi, lekin
      // to'liq kenglikda va aniq disabled state bilan.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary, // yashil ustida doim oq
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
      // Shaffof fon, matn rangidagi border va matn.
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
      // Filled input, yumshoq burchakli, fokusda brand yashil chegara.
      // `TextField` o'zi shu stilni avtomatik oladi.
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
