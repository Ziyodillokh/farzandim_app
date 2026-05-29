// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — THEME (Sprint UI.1, Duolingo-style Light asosiy)
// ─────────────────────────────────────────────────────────────────────
//
// `MaterialApp(theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme,
//  themeMode: ThemeMode.light)` deb chaqiriladi.
//
// Standartlar (Material 3 + Apple HIG + bola UX):
//   - Min tap target — 52dp+ (bola yoshiga moslashtirilgan)
//   - Body matn 16-18sp (child-friendly)
//   - Sarlavhalar Material 3 type scale
//   - useMaterial3: true
//   - Inter shrift (google_fonts) — Parent App bilan brand consistency

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  /// Min tugma height — bola yoshiga moslashtirilgan (60dp).
  static const double _minButtonHeight = 60;

  /// Min interaktiv element height (TextButton, IconButton).
  static const double _minInteractiveHeight = 52;

  // ════════════════════════════════════════════════════════════════════
  // LIGHT THEME (Sprint UI.1 asosiy — Duolingo-style)
  // ════════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgPrimary,

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textOnPrimary,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textOnAccent,
        surface: AppColors.bgPrimary,
        onSurface: AppColors.textPrimary,
        surfaceContainer: AppColors.bgSurface,
        error: AppColors.danger,
        onError: AppColors.textOnPrimary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
      ),

      // Material 3 type scale — Inter (google_fonts) + dark text on white.
      textTheme: _interTextTheme(AppColors.textPrimary, AppColors.textSecondary),

      // ─── AppBar ───
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // ─── Card ───
      cardTheme: CardThemeData(
        color: AppColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ─── Bottom Navigation ───
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgPrimary,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ─── Tugmalar (Material standard — Sprint UI.2'da PlayfulButton'ga) ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(64, _minButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, _minButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, _minInteractiveHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(_minInteractiveHeight, _minInteractiveHeight),
        ),
      ),

      // ─── Input fields ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
      ),

      // ─── Page transitions ───
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DARK THEME (fallback — themeMode.system yoki toggle uchun)
  // ════════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgPrimaryDark,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.bgCardDark,
        onSurface: Colors.white,
        error: AppColors.danger,
      ),

      textTheme: _interTextTheme(Colors.white, Colors.white70),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.bgCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // BACKWARDS COMPAT — eski kod `AppTheme.dark` ishlatadi
  // ════════════════════════════════════════════════════════════════════
  /// Sprint 4.4 legacy alias. Yangi kod `AppTheme.lightTheme` ishlatishi
  /// kerak. `themeMode.light` orqali avtomatik tanlanadi.
  static ThemeData get dark => darkTheme;

  // ════════════════════════════════════════════════════════════════════
  // PRIVATE — text theme builder
  // ════════════════════════════════════════════════════════════════════
  static TextTheme _interTextTheme(Color bodyColor, Color subduedColor) {
    return GoogleFonts.interTextTheme(
      TextTheme(
        // Sarlavhalar — bola UX uchun kattalashtirilgan
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: bodyColor,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: bodyColor,
          height: 1.1,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: bodyColor,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: bodyColor,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: bodyColor,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: bodyColor,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: bodyColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: bodyColor,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: bodyColor,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          color: subduedColor,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: bodyColor,
        ),
        labelMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: bodyColor,
        ),
        labelSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: subduedColor,
        ),
      ),
    );
  }
}
