// Loyihaning barcha ranglari shu yerda. Har rang const emas, getter —
// joriy brightness'ga qarab dark/light qiymat qaytaradi, shu tufayli
// 800+ murojaatni o'zgartirmasdan light mode qo'shilgan. Getter const
// bo'lmagani uchun `const Container(color: ...)` ishlamaydi; faqat
// `onPrimary` haqiqiy const (qiymati o'zgarmaydi).

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Joriy yorqinlik. `app.dart` har build'da theme provider'ga qarab
  /// o'rnatadi. Barcha rang getterlari shu qiymatdan foydalanadi.
  static Brightness brightness = Brightness.dark;

  static bool get isDark => brightness == Brightness.dark;

  /// Dark/light qiymatdan birini tanlaydi (ARGB int).
  static Color _c(int dark, int light) => Color(isDark ? dark : light);

  // ────────────── FON (Backgrounds) ──────────────
  // Dark: "Deep Sea" referens ranglari (#0F2027 / #203A43 / #2C5364) —
  // to'yingan teal-petrol, tepada yorug' petrol, pastda chuqur teal.
  // Frosted shisha kartalar shu teal fonni refraksiya qiladi.
  // Light: yumshoq oq-kulrang fon, oq kartalar undan ajralib turadi.

  /// Solid fon — chuqur teal #0F2027 (dark), yumshoq oq-kulrang (light).
  static Color get background => _c(0xFF0F2027, 0xFFEAEDF2);

  /// Gradient fon — yuqori rang #2C5364 (yorug' petrol-teal, yog'duni
  /// ushlaydi).
  static Color get backgroundTop => _c(0xFF2C5364, 0xFFF2F4F8);

  /// Gradient fon — pastki rang #0F2027 (chuqur teal pol).
  static Color get backgroundBottom => _c(0xFF0F2027, 0xFFDCE1EB);

  /// Karta, modal, dialog foni (solid) va GlassCard blur'siz fallback asosi.
  /// Dark: mid-teal #203A43 (gradientning o'rta tonni) — fondan yorug'roq.
  static Color get surface => _c(0xFF203A43, 0xFFFBFCFE);

  /// surface ustidagi nested element (TextField, karta ichidagi tugma).
  static Color get surfaceVariant => _c(0xFF2A4A55, 0xFFEFF2F6);

  // ────────────── ASOSIY AKSENT (Primary) — brand yashil ──────────────
  // Brand yashil faqat shu yerda (CTA fill). Dark'da biroz yorug'roq
  // (#2F6B5C) — neytral fon ustida tugma aniq ajralsin.

  static Color get primary => _c(0xFF2F6B5C, 0xFF235347);
  static Color get primaryDark => _c(0xFF235347, 0xFF1A4339);
  static Color get primaryLight => _c(0xFF3A8570, 0xFF2F6B5C);

  /// Yashil aksent — faqat foreground (ikona/matn/aksent chiziq) uchun,
  /// fill'ga ishlatilmaydi (fill — `primary`). Light'da to'q yashil
  /// (oq fonda o'qiladi), dark'da yorqin yalpiz #6ECFAA.
  static Color get accent => _c(0xFF6ECFAA, 0xFF0B2B26);

  /// `primary` ustidagi matn/ikon rangi — ikkala rejimda ham oq (to'q
  /// yashil ustida aniq o'qiladi). Haqiqiy `const`, shuning uchun uning
  /// ustidagi `const` widget'lar buzilmaydi.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ────────────── IKKILAMCHI AKSENT (Secondary) — turkuaz ──────────────

  static Color get secondary => _c(0xFF3DBFB4, 0xFF2FA99E);
  static Color get secondaryDark => _c(0xFF2A9990, 0xFF1F8A80);

  // ────────────── MATN (Text) ──────────────

  static Color get textPrimary => _c(0xFFF2F5F4, 0xFF0B2B26);
  // Dark: yorug'roq karta-tepasida ham AA (>=4.5:1) o'qilishi uchun ko'tarildi.
  static Color get textSecondary => _c(0xFFB4C0BC, 0xFF5A6B66);
  static Color get textTertiary => _c(0xFF6B7874, 0xFF7A8E88);

  // ────────────── HOLAT (Status) ──────────────
  // Light'da to'qroq (600) tuslar — oq fonda o'qiladi.

  static Color get success => _c(0xFF4ADE80, 0xFF16A34A);
  static Color get warning => _c(0xFFFBBF24, 0xFFD97706);
  static Color get error => _c(0xFFEF4444, 0xFFDC2626);
  static Color get info => _c(0xFF60A5FA, 0xFF2563EB);

  // ────────────── CHEGARALAR (Borders) ──────────────
  // Kuchaytirildi — tugma/karta fondan aniq ajralib tursin.

  static Color get border => _c(0xFF294B53, 0xFFD8DEE8);
  static Color get divider => _c(0xFF122F37, 0xFFE6EAF0);

  // ────────────── SWITCH (toggle on/off) ──────────────
  // OFF holat ikkala mode'da ham aniq ko'rinsin — eski Switch.adaptive
  // dark'da fonga singib ketardi. ON holat `activeColor` (default primary).
  /// Toggle OFF track — light/night ikkalasida ham aniq ko'rinadi.
  static Color get switchOffTrack => _c(0xFF3A4F56, 0xFFCFD6E0);

  /// Toggle OFF thumb — OFF track ustida aniq ko'rinadi.
  static Color get switchOffThumb => _c(0xFFC0CBC8, 0xFFFFFFFF);

  // ────────────── REBRAND qo'shimcha tokenlari ──────────────
  /// Grafik o'tgan-kun bar'i (muted teal — dark fonga mos).
  static Color get chartBarMuted => _c(0xFF294A52, 0xFFC5CFDB);

  /// Quick-action "binafsha" feature rangi.
  static Color get featurePurple => _c(0xFF7C6FE0, 0xFF6B5DD0);

  /// Quick-action "amber" feature rangi.
  static Color get featureAmber => _c(0xFFD4A017, 0xFFC49210);

  // ────────────── GLASS (Glassmorphism — Teal Frosted) ──────────────
  // Dark: shaffof frosted shisha (BackdropFilter blur) — orqa teal fon
  // shisha orqali ko'rinadi va refraksiya qiladi, opaque emas.
  /// Shisha yuzasi — tekis fallback fill (light 75% oq; dark gradient
  /// zaxirasi).
  static Color get glassFill => _c(0x24FFFFFF, 0xF2FBFCFE);

  /// Fill gradient tepasi (yorug'roq, frost). Faqat dark.
  static Color get glassFillTop => _c(0x30FFFFFF, 0xFFFCFDFF);

  /// Fill gradient pasti (to'qroq — konveks chuqurlik beradi). Dark.
  static Color get glassFillBottom => _c(0x17FFFFFF, 0xFFEDF1F8);

  /// Specular tepa chizig'i (~1.5px) — yuqoridan tushgan yorug'lik
  /// effekti. Faqat dark.
  static Color get glassTopHighlight => _c(0x99CFEFEA, 0x73FFFFFF);

  /// Shisha chekka — yorqin "glowing" rim.
  static Color get glassRim => _c(0x4DFFFFFF, 0x12223648);

  /// Shisha pastki chekka — nozik (asimmetrik border zaxirasi).
  static Color get glassRimBottom => _c(0x1AFFFFFF, 0x66FFFFFF);

  /// Shisha ichidagi tint — dark'da nozik teal reflektsiya (~9% #2C5364),
  /// light'da nozik yashil.
  static Color get glassTint => _c(0x182C5364, 0x0D235347);

  /// Aurora fon dog'lari (GradientBackground uchun).
  static Color get auroraPrimary => primary;
  static Color get auroraLight => primaryLight;
  static Color get auroraAccent => accent;

  // ────────────── QUICK ACTION TILE (toza shisha — referens) ──────────
  // Blur'siz, lekin toza shisha effekti: deyarli shaffof fill (fon
  // ko'rinadi), ajralishni oq fill emas, yorqin crisp rim beradi. Badge
  // ham toza shisha doira. 6 ta BackdropFilter'dan qochish uchun shunday.

  /// Tile tanasi — yuqori (juda nozik frost, fon ko'rinadi). Dark/light.
  static Color get qaTileFillTop => _c(0x14FFFFFF, 0xFFFCFDFF);

  /// Tile tanasi — past (deyarli shaffof → konveks chuqurlik).
  static Color get qaTileFillBottom => _c(0x08FFFFFF, 0xFFEBEFF7);

  /// Tile ichki teal tint (dark) — nozik reflektsiya.
  static Color get qaTileTint => _c(0x142C5364, 0x08235447);

  /// Tile rim — yorqin crisp chekka (asosiy ajralish belgisi).
  static Color get qaTileRim => _c(0x66FFFFFF, 0x12223648);

  /// Tile label matni (dark'da yorug', xira emas).
  static Color get qaTileLabel => _c(0xFFF5F8F7, 0xFF0B2B26);
}
