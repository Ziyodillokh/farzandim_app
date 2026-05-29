// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — O'LCHAMLAR (Dimensions, Spacing, Radius)
// ─────────────────────────────────────────────────────────────────────
//
// Loyihada ishlatadigan barcha o'lchamlar shu yerda. Hech bir widget'da
// `padding: EdgeInsets.all(16)` to'g'ridan-to'g'ri yozilmaydi —
// faqat shu yerdan:
//
//   Padding(padding: EdgeInsets.all(AppDimensions.md), ...)
//   BorderRadius.circular(AppDimensions.radiusM)
//
// Nega? Dizayn tizimi 8-point grid'ga asoslangan (4, 8, 16, 24, 32, 48).
// Bu Material Design va iOS HIG ikkalasi tavsiyasi — barcha vizual
// elementlar bir xil ritm bilan joylashadi, ko'zga uyg'un ko'rinadi.

/// Farzandim ilovasining o'lchamlar tizimi (spacing, radius, height).
///
/// Bu klassdan obyekt yaratilmaydi — faqat static maydonlardan
/// foydalaniladi: `AppDimensions.md`, `AppDimensions.radiusPill`, ...
class AppDimensions {
  AppDimensions._();

  // ────────────── BO'SHLIQ (Spacing) ──────────────
  //
  // Padding, margin, SizedBox uchun. 8-point grid'ga asoslangan
  // (har qadam 8 ning karralisi yoki uning yarmisi).

  /// **xs** — 4px. Eng kichik bo'shliq.
  ///
  /// Qayerda: yaqin element'lar orasi (ikonka va matn yoni-yoniga turganda).
  static const double xs = 4;

  /// **sm** — 8px. Kichik bo'shliq.
  ///
  /// Qayerda: chip'lar orasi, kichik tugma ichidagi padding.
  static const double sm = 8;

  /// **md** — 16px. Standart bo'shliq (eng ko'p ishlatiladi).
  ///
  /// Qayerda: ekranning chap-o'ng padding, karta ichidagi padding,
  /// ListTile bo'shliqlari. Default tanlov.
  static const double md = 16;

  /// **lg** — 24px. Katta bo'shliq.
  ///
  /// Qayerda: bo'limlar orasi (Section A va Section B oralig'i),
  /// katta padding'lar.
  static const double lg = 24;

  /// **xl** — 32px. Juda katta bo'shliq.
  ///
  /// Qayerda: ekran sarlavhasi va asosiy mazmun orasi,
  /// vertikal asosiy bo'limlar orasi.
  static const double xl = 32;

  /// **xxl** — 48px. Eng katta bo'shliq.
  ///
  /// Qayerda: bo'sh ekranlardagi katta hero bo'shliq, ekran tepasidagi
  /// status bar'dan keyingi katta padding.
  static const double xxl = 48;

  // ────────────── BURCHAK RADIUSI (Border Radius) ──────────────
  //
  // Container, Card, Button burchak yumshatish uchun.

  /// **radiusS** — 8px. Kichik radius.
  ///
  /// Qayerda: Chip, kichik badge, kompakt tugmalar.
  static const double radiusS = 8;

  /// **radiusM** — 16px. O'rta radius (default).
  ///
  /// Qayerda: kartalar, TextField, modal oynalar,
  /// BottomSheet yuqori burchaklari.
  static const double radiusM = 16;

  /// **radiusL** — 24px. Katta radius.
  ///
  /// Qayerda: katta kartalar, hero karta'lar (dashboard'dagi
  /// "Bugun sarflangan vaqt" tipidagi).
  static const double radiusL = 24;

  /// **radiusPill** — 999px. To'liq dumaloq (pill shape).
  ///
  /// Qayerda: PrimaryButton va SecondaryButton (CLAUDE.md tugma uslubi),
  /// avatar (`CircleAvatar` o'rniga), to'liq dumaloq chip'lar.
  ///
  /// Qiymat 999 — chunki BorderRadius.circular() o'lchamning yarmidan
  /// kattaroq qiymat olsa, avtomatik to'liq pill shaklini hosil qiladi.
  static const double radiusPill = 999;

  // ────────────── KOMPONENTLAR BALANDLIGI ──────────────

  /// Tugma standart balandligi — 56px.
  ///
  /// CLAUDE.md tugma stilidan: PrimaryButton va SecondaryButton ikkalasi
  /// 56dp baland. Bu Material Design'dan ham kattaroq (default 48dp) —
  /// Farzandim'da yirik, qulay tugmalar.
  ///
  /// Qayerda: PrimaryButton, SecondaryButton.
  static const double buttonHeight = 60;

  /// TextField standart balandligi — 56px.
  ///
  /// Tugmalar bilan bir xil balandlik — formalardagi vizual uyg'unlik uchun.
  static const double inputHeight = 56;

  // ────────────── IKONKA O'LCHAMLARI ──────────────

  /// Kichik ikonka — 16px. Inline matn ichida.
  static const double iconS = 16;

  /// Standart ikonka — 24px. Eng ko'p ishlatiladi (Flutter default).
  ///
  /// Qayerda: AppBar action ikonkalari, ListTile leading/trailing,
  /// IconButton ichida.
  static const double iconM = 24;

  /// Katta ikonka — 32px.
  ///
  /// Qayerda: empty state ekranidagi katta ikonka, dashboard'dagi
  /// quick action tugmalaridagi ikonka.
  static const double iconL = 32;
}
