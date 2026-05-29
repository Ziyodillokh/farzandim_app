// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — O'ZBEKISTON HUDUDLARI (Regions)
// ─────────────────────────────────────────────────────────────────────
//
// "Bola qo'shish" formasidagi "Hudud" dropdown'i shu ro'yxatdan
// foydalanadi. Firestore'da `children/{id}.region` maydoni shu
// string'lardan biri bo'ladi.
//
// Tartib: Toshkent shahri va viloyati birinchi (eng ko'p foydalanuvchi
// — UX qulaylik), keyin qolgani alfavit bo'yicha.
//
// Kelajakda kengaytirsak (tumanlar): yangi struktura kerak bo'ladi —
// `Map<String, List<String>>` (viloyat → tumanlar). Hozir Slice MVP
// uchun faqat viloyat darajasi yetarli.

/// O'zbekiston Respublikasi viloyatlari va Toshkent shahri ro'yxati.
///
/// Foydalanish:
/// ```dart
/// CustomDropdown<String>(
///   items: UzbekistanRegions.regions
///       .map((r) => DropdownMenuItem(value: r, child: Text(r)))
///       .toList(),
///   ...
/// )
/// ```
class UzbekistanRegions {
  UzbekistanRegions._();

  /// 14 ta hudud — string ko'rinishida (Firestore'ga shu shaklda
  /// saqlanadi).
  static const List<String> regions = [
    'Toshkent shahri',
    'Toshkent viloyati',
    'Andijon',
    'Buxoro',
    "Farg'ona",
    'Jizzax',
    'Namangan',
    'Navoiy',
    'Qashqadaryo',
    'Samarqand',
    'Sirdaryo',
    'Surxondaryo',
    'Xorazm',
    "Qoraqalpog'iston",
  ];
}
