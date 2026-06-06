// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — RANG TIZIMI (Color System) — Light + Dark
// ─────────────────────────────────────────────────────────────────────
//
// Loyihaning BARCHA ranglari shu fayldagina yashaydi. Widget'larda
// `AppColors.background`, `AppColors.surface`, ... ishlatiladi.
//
// **Theme-aware (kam-churn arxitektura):** har rang `static const` emas,
// balki GETTER. Getter joriy `brightness` qiymatiga qarab dark yoki light
// rangni qaytaradi. Shu sababli 800+ murojaatni o'zgartirmasdan light mode
// qo'shildi — `app.dart` har build'da `AppColors.brightness` ni theme
// provider'dan o'rnatadi.
//
// Eslatma: getter `const` emas — shuning uchun `const Container(color:
// AppColors.background)` ishlamaydi. Bunday joylardan `const` olib tashlandi.
// `onPrimary` esa haqiqiy `const` (qiymati o'zgarmaydi) — uning const
// ishlatilishi buzilmaydi.

import 'package:flutter/material.dart';

/// Farzandim rang palitrasi (light + dark). Obyekt yaratilmaydi — faqat
/// static getterlar: `AppColors.primary`, `AppColors.background`, ...
class AppColors {
  AppColors._();

  /// Joriy yorqinlik. `app.dart` har build'da theme provider'ga qarab
  /// o'rnatadi. Barcha rang getterlari shu qiymatdan foydalanadi.
  static Brightness brightness = Brightness.dark;

  static bool get isDark => brightness == Brightness.dark;

  /// Dark/light qiymatdan birini tanlaydi (ARGB int).
  static Color _c(int dark, int light) => Color(isDark ? dark : light);

  // ────────────── FON (Backgrounds) ──────────────
  // Dark: gradient avval surface'ga juda yaqin edi (kartalar yopishib
  // qolardi) — endi gradient QORAYTIRILDI, surface bo'rtib chiqadi.
  // Light: yumshoq oq-kulrang fon, oq kartalar aniq ajralib turadi.

  /// Solid fon (asosan onPrimary qora matn uchun emas — endi `onPrimary`).
  static Color get background => _c(0xFF0A0A12, 0xFFF2F4F8);

  /// Gradient fon — yuqori rang. Light'da yengil kulrang (sof oq EMAS) —
  /// shunda oq `surface` kartalar tepada ham fonga yopishmasdan ajraladi.
  static Color get backgroundTop => _c(0xFF13161F, 0xFFEDEFF3);

  /// Gradient fon — pastki rang.
  static Color get backgroundBottom => _c(0xFF080810, 0xFFE9ECF2);

  /// Karta, modal, dialog, AppBar foni — fondan aniq ajralib turadi.
  static Color get surface => _c(0xFF1E1F28, 0xFFFFFFFF);

  /// surface ustidagi nested element (TextField, karta ichidagi tugma).
  static Color get surfaceVariant => _c(0xFF282933, 0xFFEEF1F6);

  // ────────────── ASOSIY AKSENT (Primary) — lime brand ──────────────
  // Brand rangi ikkala rejimda bir xil (lime green + qora matn) — kuchli
  // kontrast, tugmalar ikkala fonda ham bo'rtib chiqadi.

  static Color get primary => _c(0xFFC5F562, 0xFFC5F562);
  static Color get primaryDark => _c(0xFFA3CE4F, 0xFFA3CE4F);
  static Color get primaryLight => _c(0xFFD4F783, 0xFFD4F783);

  /// Yashil AKSENT — FOREGROUND (ikona/matn/aksent chiziq) uchun. `primary`
  /// (lime) FILL uchun ishlatiladi, ammo lime oq/och fon ustida yuvilib
  /// ketadi. `accent` esa light'da TO'Q yashil (oq fonda aniq o'qiladi),
  /// dark'da o'sha lime. ⚠️ Tugmalar/FILL'larga TEGMAYDI — faqat foreground.
  static Color get accent => _c(0xFFC5F562, 0xFF3F7E16);

  /// Lime (primary) USTIDAGI matn/ikon rangi — ikkala rejimda ham DOIM
  /// to'q (lime yorqin). `background` o'rniga shu ishlatiladi (light mode'da
  /// `background` och bo'lib qoladi → lime ustida o'qilmaydi). Bu HAQIQIY
  /// `const` — uning ustidagi `const` widget'lar buzilmaydi.
  static const Color onPrimary = Color(0xFF0E1208);

  // ────────────── IKKILAMCHI AKSENT (Secondary) — turkuaz ──────────────

  static Color get secondary => _c(0xFF3DBFB4, 0xFF2FA99E);
  static Color get secondaryDark => _c(0xFF2A9990, 0xFF1F8A80);

  // ────────────── MATN (Text) ──────────────

  static Color get textPrimary => _c(0xFFFFFFFF, 0xFF14161D);
  static Color get textSecondary => _c(0xFF9999A8, 0xFF5A5D6B);
  static Color get textTertiary => _c(0xFF6B6B78, 0xFF686C7A);

  // ────────────── HOLAT (Status) ──────────────
  // Light'da to'qroq (600) tuslar — oq fonda o'qiladi.

  static Color get success => _c(0xFF4ADE80, 0xFF16A34A);
  static Color get warning => _c(0xFFFBBF24, 0xFFD97706);
  static Color get error => _c(0xFFEF4444, 0xFFDC2626);
  static Color get info => _c(0xFF60A5FA, 0xFF2563EB);

  // ────────────── CHEGARALAR (Borders) ──────────────
  // Kuchaytirildi — tugma/karta fondan aniq ajralib tursin.

  static Color get border => _c(0xFF34353F, 0xFFCFD4DD);
  static Color get divider => _c(0xFF24252E, 0xFFE8EBF0);
}
