// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — SOYA (Elevation) TIZIMI
// ─────────────────────────────────────────────────────────────────────
//
// Premium chuqurlik uchun yumshoq, ko'p-qatlamli soyalar. Kartalar tekis
// ko'rinmasdan "qalqib turgan" hissi beradi. Theme-aware: light'da yumshoq
// salqin-tusli soya, dark'da chuqurroq qora. Layout O'ZGARMAYDI — faqat soya.
//
// Foydalanish:
// ```dart
// BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.card, ...)
// ```
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Premium soya tokenlari (theme-aware getterlar — toggle'da yangilanadi).
class AppShadows {
  AppShadows._();

  /// Karta/surface uchun yumshoq soya (eng ko'p ishlatiladigan).
  static List<BoxShadow> get card => AppColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x42000000), // qora ~26%
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ]
      : const [
          // Salqin navy-tusli yumshoq soya — premium, sof qora emas.
          BoxShadow(
            color: Color(0x14171A2E),
            blurRadius: 22,
            offset: Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ];

  /// Ko'tarilgan element (modal sheet, picker, FAB) — kuchliroq soya.
  static List<BoxShadow> get elevated => AppColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x5C000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1F171A2E),
            blurRadius: 34,
            offset: Offset(0, 16),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ];

  /// Brand glow — lime tugma ostidagi nozik yog'du (premium CTA).
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: AppColors.isDark ? 0.30 : 0.32),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -3,
        ),
      ];
}
