// Loyihaning barcha o'lchamlari (spacing, radius, balandliklar) shu yerda —
// widget'larda raqamlar qo'lda yozilmaydi. 8-point grid'ga asoslangan,
// shunda elementlar bir xil ritmda joylashadi.

class AppDimensions {
  AppDimensions._();

  // ────────────── BO'SHLIQ (Spacing) ──────────────

  /// 4px — eng kichik bo'shliq (ikonka va matn yonma-yon turganda).
  static const double xs = 4;

  /// 8px — chip'lar orasi, kichik tugma padding'i.
  static const double sm = 8;

  /// 16px — standart bo'shliq, default tanlov (ekran chetlari,
  /// karta ichi).
  static const double md = 16;

  /// 24px — bo'limlar orasi, katta padding'lar.
  static const double lg = 24;

  /// 32px — sarlavha va asosiy mazmun orasi.
  static const double xl = 32;

  /// 48px — eng katta bo'shliq (hero bo'shliqlar).
  static const double xxl = 48;

  // ────────────── BURCHAK RADIUSI (Border Radius) ──────────────

  /// 8px — chip, kichik badge, kompakt tugmalar.
  static const double radiusS = 8;

  /// 16px — default radius (kartalar, TextField, bottom sheet).
  static const double radiusM = 16;

  /// 24px — katta va hero kartalar.
  static const double radiusL = 24;

  /// 24px — dashboard'dagi quick action tile'lar.
  static const double radiusTile = 24;

  /// 999px — to'liq pill shakl (tugmalar, avatar, dumaloq chip'lar).
  /// O'lcham yarmidan katta radius berilsa avtomatik pill bo'ladi.
  static const double radiusPill = 999;

  // ────────────── KOMPONENTLAR BALANDLIGI ──────────────

  /// Tugma balandligi — 60px (PrimaryButton, SecondaryButton).
  /// Material default'idan (48) ataylab kattaroq — yirik, qulay tugmalar.
  static const double buttonHeight = 60;

  /// TextField balandligi — 56px, formalarda tugmalarga yaqin
  /// turishi uchun.
  static const double inputHeight = 56;

  // ────────────── IKONKA O'LCHAMLARI ──────────────

  /// Kichik ikonka — 16px, inline matn ichida.
  static const double iconS = 16;

  /// Standart ikonka — 24px (Flutter default).
  static const double iconM = 24;

  /// Katta ikonka — 32px (empty state, quick action tugmalari).
  static const double iconL = 32;
}
