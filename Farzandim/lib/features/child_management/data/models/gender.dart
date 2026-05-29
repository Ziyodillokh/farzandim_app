// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — JINSI (Gender enum)
// ─────────────────────────────────────────────────────────────────────
//
// Bola jinsini ifodalash uchun enum. "Bola qo'shish" formasida
// (Bosqich 2.2) tanlanadi va `Child` modelida saqlanadi. Default
// avatar sticker'i jinsiga qarab tanlanadi (boy_*.svg / girl_*.svg).
//
// Nega `String` emas? `'male'` deb yozsak `'mael'` tipo'si kompilatsiyada
// ushlanmaydi — runtime'da xato. Enum bilan IDE avtomatik to'ldiradi
// va Dart bizni `switch` ichida har variantni ko'rishga majburlaydi.

/// Bola jinsi.
///
/// Faqat ikki tanlov: erkak yoki ayol. Qo'shimcha kategoriyalar
/// hozircha kerak emas (Slice MVP).
enum Gender {
  /// O'g'il bola.
  male,

  /// Qiz bola.
  female,
}

/// `Gender` enum'iga UI uchun foydali metodlarni qo'shadi.
///
/// **Foydalanish:**
/// ```dart
/// Text(child.gender.label) // "O'g'il" yoki "Qiz"
/// ```
///
/// Bu kengaytirma fayllar dizayn'i bo'yicha tilga (lokalizatsiyaga)
/// bog'liq qism — Bosqich 7'da `easy_localization` kelganda
/// `'gender.male'.tr()` orqali almashtirib qo'yamiz.
extension GenderX on Gender {
  /// O'zbek tilidagi yorlig'i — UI'da ko'rsatish uchun.
  String get label {
    switch (this) {
      case Gender.male:
        return "O'g'il";
      case Gender.female:
        return 'Qiz';
    }
  }
}
