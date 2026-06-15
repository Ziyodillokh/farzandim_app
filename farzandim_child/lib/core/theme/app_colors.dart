// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — COLOR SYSTEM (Sprint UI.1, Duolingo-inspired)
// ─────────────────────────────────────────────────────────────────────
//
// Light theme asosiy (bola UX uchun). Duolingo design language:
// playful, yorug', child-friendly, WCAG AA compliant.
//
// Usage guidelines:
//   primary    — Main CTA tugmalar, success, FARO accent
//   secondary  — Info, location, navigation hints
//   accent     — Rewards, stars, balls (kam ishlatish)
//   warning    — Battery low, schedule ogohlantirishlar
//   danger     — Faqat SOS, emergency (juda kam)
//
// Hech bir widget'da to'g'ridan-to'g'ri `Color(0xFF...)` yozilmaydi —
// faqat shu yerdan: `AppColors.primary`, `AppColors.bgPrimary`, ...

import 'package:flutter/material.dart';

/// Farzandim Child App color tokens.
class AppColors {
  AppColors._();

  // ============ PRIMARY (Aqua / Siyan brend) ============
  /// Asosiy CTA tugma fon, FARO accent. (Avval Duolingo yashil edi.)
  static const Color primary = Color(0xFF16B5C9);

  /// Hover state (web), pressed state (mobile).
  static const Color primaryHover = Color(0xFF0E7490);

  /// Disabled tugma fon.
  static const Color primaryDisabled = Color(0xFF8FCBD6);

  /// 3D button pastki shadow (Sprint UI.2 PlayfulButton uchun).
  static const Color primaryShadow = Color(0xFF0E7490);

  // ============ SECONDARY (Friendly Blue) ============
  /// Info, location, navigation hints uchun.
  static const Color secondary = Color(0xFF1CB0F6);

  static const Color secondaryHover = Color(0xFF0E96D6);
  static const Color secondaryShadow = Color(0xFF0E96D6);

  // ============ ACCENT (Sunshine Yellow) ============
  /// Rewards, stars, achievements — kam ishlatish (<5%).
  static const Color accent = Color(0xFFFFC800);

  static const Color accentHover = Color(0xFFE5B400);
  static const Color accentShadow = Color(0xFFE5B400);

  // ============ STATUS ============
  /// Battery low, schedule warnings.
  static const Color warning = Color(0xFFFF9600);
  static const Color warningShadow = Color(0xFFCC7700);

  /// SOS, emergency (juda kam ishlatish).
  static const Color danger = Color(0xFFFF4B4B);
  static const Color dangerShadow = Color(0xFFCC3030);

  /// Success — universal yashil (brend aqua'dan ajratilgan; ✓, "yuborildi").
  static const Color success = Color(0xFF22C55E);

  /// Info = secondary.
  static const Color info = secondary;

  /// Sprint 4.4 legacy alias — eski kod `AppColors.error` ishlatadi.
  /// Yangi kod `AppColors.danger` ishlatishi kerak.
  static const Color error = danger;

  // ============ BACKGROUNDS (Light Mode — asosiy) ============
  /// Scaffold asosiy fon (oq).
  static const Color bgPrimary = Color(0xFFFFFFFF);

  /// Surface — kartalar, dialog'lar, BottomSheet (very light gray).
  static const Color bgSurface = Color(0xFFF7F7F7);

  /// Soft yellow surface — rewards/achievements section'lari.
  static const Color bgAccent = Color(0xFFFFF8E7);

  /// Cosmic sky tint — onboarding, hero sections.
  static const Color bgSky = Color(0xFFE0F2FE);

  // ============ BACKGROUNDS (Dark Mode — Telegram night style) ============
  /// Asosiy fon (chuqur tunqorong'i).
  static const Color bgPrimaryDark = Color(0xFF0E1117);

  /// Surface — kartalar, dialog, bottomSheet (biroz yengilroq).
  static const Color bgSurfaceDark = Color(0xFF161B22);

  /// Yuqori-darajali karta fon (gradient/hover uchun).
  static const Color bgCardDark = Color(0xFF1C232C);

  /// Border/divider — kam ko'rinadigan ajratuvchi chiziq.
  static const Color borderDark = Color(0xFF2A323D);

  /// Divider — yanada yengil ajratish.
  static const Color dividerDark = Color(0xFF1F262F);

  // ============ TEXT (Dark Mode) ============
  static const Color textPrimaryDark = Color(0xFFE6EDF3);
  static const Color textSecondaryDark = Color(0xFF8B96A5);
  static const Color textTertiaryDark = Color(0xFF6A7585);

  // ============ TEXT ============
  /// Asosiy matn (dark navy, oq fonda).
  static const Color textPrimary = Color(0xFF1A2B3B);

  /// Ikkilamchi matn.
  static const Color textSecondary = Color(0xFF4A5568);

  /// Uchlamchi matn (helper, caption).
  static const Color textTertiary = Color(0xFF94A3B8);

  /// Primary tugma ichidagi matn (oq).
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Accent (sariq) tugma ichidagi matn (dark).
  static const Color textOnAccent = Color(0xFF1A2B3B);

  // ============ SURFACES (alias — eski kod uchun) ============
  /// Sprint 4.4 legacy alias — eski kod `AppColors.surface` ishlatadi.
  /// Yangi kod `AppColors.bgSurface` ishlatishi kerak.
  static const Color surface = bgSurface;
  static const Color surfaceVariant = Color(0xFFEDF2F7);

  // ============ DIVIDERS / BORDERS ============
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFCBD5E0);

  // ============ SHADOWS ============
  /// Light shadow (kartalar uchun, 6% opacity).
  static const Color shadowLight = Color(0x0F1A2B3B);

  /// Medium shadow (8% opacity).
  static const Color shadowMedium = Color(0x141A2B3B);

  /// FAB sariq glow (16% accent).
  static const Color shadowFAB = Color(0x29FFC800);

  // ============ UZBEK PRIDE (use sparingly, <5%) ============
  /// Sprint UI.1 — milliy element'lar, splash, branding accent.
  static const Color uzbFlagBlue = Color(0xFF1EB5E5);
  static const Color uzbFlagRed = Color(0xFFCE1126);
  static const Color uzbFlagGreen = Color(0xFF1EAF53);

  // ============ CATEGORY PALETTE (Sprint UI.1) ============
  /// Gamification, ranking, achievement, audiobooks uchun per-kategoriya
  /// accent ranglar. Default Material palette'ga asoslangan. Backend
  /// kelajakda har kategoriya uchun rang yuborsa, shu konstantalar
  /// fallback bo'ladi.
  static const Color catPurple = Color(0xFF8B5CF6);
  static const Color catViolet = Color(0xFFA78BFA);
  static const Color catIndigo = Color(0xFF6366F1);
  static const Color catBlue = Color(0xFF60A5FA);
  static const Color catTeal = Color(0xFF14B8A6);
  static const Color catEmerald = Color(0xFF10B981);
  static const Color catGreen = Color(0xFF50C878);
  static const Color catEmeraldLight = Color(0xFF34D399);
  static const Color catAmber = Color(0xFFFBBF24);
  static const Color catGold = Color(0xFFFFD700);
  static const Color catOrange = Color(0xFFFB923C);
  static const Color catOrangeDark = Color(0xFFF97316);
  static const Color catOrangeLight = Color(0xFFFFA726);
  static const Color catOrangeWarm = Color(0xFFFFB627);
  static const Color catPink = Color(0xFFEC4899);
  static const Color catPinkRose = Color(0xFFE85D75);
  static const Color catPinkVibrant = Color(0xFFE4405F);
  static const Color catRed = Color(0xFFFF5252);
  static const Color catRedDark = Color(0xFFD32F2F);
  static const Color catLavender = Color(0xFF8B95DD);
  static const Color catLavenderDark = Color(0xFF5963C9);
  static const Color catMint = Color(0xFF4DC4B7);
  static const Color catLime = Color(0xFFD0FF6E);
  static const Color catLimeBright = Color(0xFFC5F562);

  // ============ PARVOZ REDESIGN (Night) — Stitch "Parvoz UI" ============
  // Kutubxona va keyingi sahifalar uchun yangi NIGHT palitra (Stitch
  // "Parvoz UI Redesign" loyihasi). Faqat yangi (redizayn) sahifalarda
  // ishlatiladi — mavjud ekranlarga tegmaydi (bosqichma-bosqich migratsiya).
  // Light mode keyin alohida qo'shiladi.
  /// Chuqur navy fon (sahifa orqa foni).
  static const Color parvozBg = Color(0xFF0B1C30);

  /// Kartalar, tugmalar, segment, header tugmalari foni.
  static const Color parvozSurface = Color(0xFF162B45);

  /// Yengilroq surface — chip/placeholder/rasm orqa foni.
  static const Color parvozSurfaceHigh = Color(0xFF1E3552);

  /// Aqua aksent — logo, faol tab, CTA tugma, ko'rishlar soni. (Avval yashil.)
  static const Color parvozGreen = Color(0xFF22D3EE);

  /// Aqua ustidagi matn/ikon (to'q navy — yorqin aqua'da a'lo kontrast).
  static const Color parvozOnGreen = Color(0xFF0B1C30);

  /// Ko'k aksent — faol kategoriya chip / faol nav.
  static const Color parvozBlue = Color(0xFF2170E4);

  /// Asosiy matn (deyarli oq).
  static const Color parvozText = Color(0xFFFFFFFF);

  /// Ikkilamchi matn (tavsif, kategoriya — muted blue-gray).
  static const Color parvozTextDim = Color(0xFF9CA3AF);

  /// Nozik chegara (white/5) — kartalar, nofaol chip.
  static const Color parvozBorder = Color(0x0DFFFFFF);

  /// Kuchliroq chegara (white/10) — floating nav.
  static const Color parvozBorderStrong = Color(0x1AFFFFFF);

  /// 'YANGI DARS' badge — to'q-sariq (Premium Edition).
  static const Color parvozBadge = Color(0xFFF39C12);

  // ============ LEGACY ALIASES (Sprint 4.4 backwards compat) ============
  /// Sprint 4.4'da `primaryDark` ishlatilgan — yangi `primaryHover` alias.
  static const Color primaryDark = primaryHover;

  /// Sprint 4.4'da `backgroundTop` ishlatilgan (gradient) — endi flat,
  /// alias `bgPrimary`.
  static const Color backgroundTop = bgPrimary;

  /// Sprint 4.4'da `backgroundBottom` ishlatilgan — alias `bgPrimary`.
  static const Color backgroundBottom = bgPrimary;
}

// ═════════════════════════════════════════════════════════════════════
// AdaptiveColors — Theme.brightness'ga qarab to'g'ri palette qaytaradi.
// ═════════════════════════════════════════════════════════════════════
//
// Widget'lar `context.adaptive.surface` deb chaqirsa, dark mode'da
// avtomatik dark surface, light mode'da light surface keladi.
// Hardcoded `AppColors.bgSurface` o'rniga shu helper ishlatilsa,
// butun ilova bir tugma bilan dark/light bo'la oladi.

extension AdaptivePaletteX on BuildContext {
  AdaptivePalette get adaptive => AdaptivePalette._(
        Theme.of(this).brightness == Brightness.dark,
      );
}

class AdaptivePalette {
  const AdaptivePalette._(this.isDark);
  final bool isDark;

  Color get bgPrimary =>
      isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimary;
  Color get bgSurface =>
      isDark ? AppColors.bgSurfaceDark : AppColors.bgSurface;
  Color get bgCard =>
      isDark ? AppColors.bgCardDark : AppColors.bgSurface;
  Color get textPrimary =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get textTertiary =>
      isDark ? AppColors.textTertiaryDark : AppColors.textTertiary;
  Color get border => isDark ? AppColors.borderDark : AppColors.border;
  Color get divider => isDark ? AppColors.dividerDark : AppColors.divider;
  Color get surface => bgCard; // legacy alias
}
