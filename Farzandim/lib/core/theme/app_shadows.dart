// Soya tokenlari — kartalarga "qalqib turgan" chuqurlik beradi.
// Theme-aware: light'da yumshoq salqin-tusli soya, dark'da chuqurroq qora.
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Soya tokenlari — theme-aware getterlar, toggle'da yangilanadi.
class AppShadows {
  AppShadows._();

  /// Karta/surface uchun yumshoq soya (eng ko'p ishlatiladigan).
  static List<BoxShadow> get card => AppColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x50000000), // neytral fonda biroz chuqurroq qora
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ]
      : const [
          // Salqin yumshoq "ko'tarilish" — kulrang fon ustida karta premium
          // chuqurlik bilan suzadi (sof qora emas, salqin slate tusli).
          BoxShadow(
            color: Color(0x1A1B2A3A),
            blurRadius: 24,
            offset: Offset(0, 10),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Color(0x0D1B2A3A),
            blurRadius: 6,
            offset: Offset(0, 2),
            spreadRadius: -2,
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
            color: Color(0x1F0B2B26),
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

  /// Brand glow — CTA tugma ostidagi nozik yog'du.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: AppColors.isDark ? 0.28 : 0.25),
      blurRadius: 18,
      offset: const Offset(0, 8),
      spreadRadius: -3,
    ),
  ];

  /// Shisha karta uchun ko'p-qatlamli "floating" soya.
  static List<BoxShadow> get glass => AppColors.isDark
      ? [
          // Chuqur qora float — karta fon ustidan baland "suzadi".
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -6,
          ),
          // Teal "neon" halo — shisha kartani teal yorug'lik bilan o'raydi.
          BoxShadow(
            color: const Color(0xFF3DBFB4).withValues(alpha: 0.09),
            blurRadius: 28,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
          // Mint chekka jilosi — juda nozik.
          BoxShadow(
            color: const Color(0xFF6ECFAA).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -10,
          ),
          // Kontakt soyasi — yer bilan ulanish.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
      : [
          // Premium salqin "floating" — karta fon ustidan yumshoq suzadi.
          BoxShadow(
            color: const Color(0xFF1B2A3A).withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ];

  /// Quick action tile — toza neytral float va nozik rim shadow.
  /// Rangli halo yo'q: shisha ortida rang bo'lmaydi (referens uslubi).
  static List<BoxShadow> get qaTile => AppColors.isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          // Yuqori rim shadow (nozik yorug' chekka).
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF0B2B26).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
}
