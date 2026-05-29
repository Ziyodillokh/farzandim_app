// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — RANG TIZIMI (Color System)
// ─────────────────────────────────────────────────────────────────────
//
// Loyihaning BARCHA ranglari shu fayldagina yashaydi.
// Hech bir widget'da to'g'ridan-to'g'ri `Color(0xFF...)` yozilmaydi —
// faqat shu yerdan olib ishlatamiz:
//
//   Container(color: AppColors.background)
//   Text('Salom', style: TextStyle(color: AppColors.textPrimary))
//
// Nega? Kelajakda biror rangni o'zgartirsangiz (masalan, brand rangi
// yangilansa), faqat shu faylni o'zgartirasiz — butun ilova yangilanadi.
//
// Dizayn falsafasi: Dark mode (qora fon, oq matn, lime green aksent).

import 'package:flutter/material.dart';

/// Farzandim ilovasining rang palitrasi.
///
/// Bu klassdan obyekt yaratilmaydi — faqat static maydonlardan
/// foydalaniladi: `AppColors.primary`, `AppColors.background`, ...
class AppColors {
  // Private konstruktor — `AppColors()` deb chaqirib bo'lmaydi.
  AppColors._();

  // ────────────── FON RANGLARI (Backgrounds) ──────────────

  /// Solid fon — kam ishlatamiz, asosan PrimaryButton'dagi qora matn rangi
  /// uchun (`onPrimary`). Ekranlar fon'i `GradientBackground` orqali
  /// `backgroundTop` → `backgroundBottom` gradient sifatida quriladi.
  static const Color background = Color(0xFF0A0A12);

  /// Gradient fonning **yuqori** rangi — moviy tusli to'q kulrang.
  /// PDF dizayni'dan olingan.
  ///
  /// Qayerda: `GradientBackground` widget'i (chap.col), Scaffold ortida
  /// `scaffoldBackgroundColor: Colors.transparent` orqali ko'rinadi.
  static const Color backgroundTop = Color(0xFF1B212F);

  /// Gradient fonning **pastki** rangi — chuqur qora.
  /// PDF dizayni'dan olingan.
  static const Color backgroundBottom = Color(0xFF0A0A16);

  /// Karta, modal va dialog'lar uchun fon.
  ///
  /// `background`'dan bir oz och — element fondan ajralib turishi uchun.
  ///
  /// Qayerda: `Card`, `Dialog`, `BottomSheet`, `AppBar`,
  /// dashboard'dagi statistika karta'lari.
  static const Color surface = Color(0xFF1C1C24);

  /// `surface`'dan yana bir oz ko'tarilgan sath.
  ///
  /// Qayerda: `TextField` fon, surface ustidagi nested element'lar
  /// (masalan, kartani ichidagi tugma).
  static const Color surfaceVariant = Color(0xFF252530);

  // ────────────── ASOSIY AKSENT (Primary) ──────────────
  //
  // PDF dizayni bo'yicha UI palitra: lime green tugmalar, faol holatlar,
  // aksent. **Bu logo brand sxemasidan farq qiladi** — logo'lar moviy/
  // turkuaz, lekin UI lime green. Ikki sxemani aralashtirmaymiz.

  /// Lime green — UI'ning **asosiy aksent rangi**.
  ///
  /// Yorqin, e'tiborni jalb qiluvchi, "harakat" rangi. Qora fonda
  /// kuchli kontrast hosil qiladi (qora matn yaxshi o'qiladi).
  ///
  /// Qayerda: `PrimaryButton` fon, "Davom etish" / "Saqlash" tugmalari,
  /// faol toggle, tanlangan tab, ahamiyatli ikonkalar
  /// (oila kodi raqamlari).
  static const Color primary = Color(0xFFC5F562);

  /// `primary`'ning to'qroq variant'i.
  ///
  /// Qayerda: tugma **bosilganda** (pressed state), to'q lime aksent.
  static const Color primaryDark = Color(0xFFA3CE4F);

  /// `primary`'ning yorug'roq variant'i.
  ///
  /// Qayerda: hover holati (web/desktop), kuchsizroq aksent, soft
  /// highlight fon.
  static const Color primaryLight = Color(0xFFD4F783);

  // ────────────── IKKILAMCHI AKSENT (Secondary) ──────────────
  //
  // Turkuaz — logo brand'idan kelgan. UI'da kam ishlatiladi (asosan
  // logo PNG'larida ko'rinadi). Maxsus aksent kerak bo'lganda foydali
  // (masalan, statistika diagrammalari, "yangi" badge'lar).

  /// Turkuaz — ikkilamchi aksent rangi.
  ///
  /// Logodan olingan. UI'da kam, lekin maxsus joylar uchun saqlangan
  /// (chart'lar, badge'lar).
  static const Color secondary = Color(0xFF3DBFB4);

  /// `secondary`'ning to'qroq variant'i.
  ///
  /// Qayerda: turkuaz aksent pressed state, dark teal badge'lar.
  static const Color secondaryDark = Color(0xFF2A9990);

  // ────────────── MATN RANGLARI (Text) ──────────────

  /// Asosiy matn — eng yuqori kontrast.
  ///
  /// Qayerda: sarlavhalar (`headlineLarge`, `titleLarge`),
  /// asosiy paragrafalar, AppBar sarlavha, faol holatdagi yozuvlar.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Ikkilamchi matn — kontrast pastroq, e'tibor olmaydi.
  ///
  /// Qayerda: ListTile `subtitle`, "5 daqiqa oldin" kabi vaqt yorlig'i,
  /// description matni, kichik tushuntirishlar.
  static const Color textSecondary = Color(0xFF9999A8);

  /// Eng kuchsiz matn — placeholder, hint, disabled holatlar.
  ///
  /// Qayerda: `TextField` hint matni ("Ismni kiriting..."),
  /// **disabled** tugma matni, "ma'lumot yo'q" kabi bo'sh holat yozuvlari.
  static const Color textTertiary = Color(0xFF6B6B78);

  // ────────────── HOLAT RANGLARI (Status) ──────────────

  /// Yashil — muvaffaqiyat, faol, online.
  ///
  /// Qayerda: "Saqlandi" snackbar, bola online belgisi (avatar uchidagi
  /// yashil nuqta), success xabarlar, ✓ ikonka.
  static const Color success = Color(0xFF4ADE80);

  /// Sariq — diqqat, ogohlantirish (xato emas).
  ///
  /// Qayerda: "Batareya 20%dan past", "Joylashuv 1 soat oldin yangilangan",
  /// warning snackbar, "tasdiqlanmagan" yorlig'i.
  static const Color warning = Color(0xFFFBBF24);

  /// Qizil — xato, xavf, SOS.
  ///
  /// Qayerda: SOS bildirishnoma karta, xato xabarlari ("Internet yo'q"),
  /// "O'chirish" tugmasi, validatsiya xato matni, batareya juda kam (5%).
  static const Color error = Color(0xFFEF4444);

  /// Ko'k — neutral ma'lumot, link.
  ///
  /// Qayerda: info snackbar, "Batafsil" linklari, ma'lumot ikonkalari (ⓘ),
  /// neutral xabarlar (xato ham, muvaffaqiyat ham emas).
  static const Color info = Color(0xFF60A5FA);

  // ────────────── CHEGARALAR (Borders) ──────────────

  /// Tashqi chegara chizig'i.
  ///
  /// `surface`'dan bir oz yorug'roq — sezilarli, lekin urg'u bermaydi.
  ///
  /// Qayerda: `TextField` border, `OutlinedButton` chegarasi,
  /// karta atrofidagi chiziq.
  static const Color border = Color(0xFF2A2A35);

  /// Yumshoq ajratuvchi chiziq — eng xira.
  ///
  /// Qayerda: ListView ichidagi `Divider`, sozlamalar bo'limlarini
  /// ajratuvchi gorizontal chiziq.
  static const Color divider = Color(0xFF1F1F28);
}
