// O'zbekiston hududlari ro'yxati — "Bola qo'shish" formasidagi dropdown
// shu ro'yxatdan foydalanadi, `children/{id}.region` ham shu string'lardan.

/// Viloyatlar va Toshkent shahri. Toshkent birinchi (eng ko'p
/// foydalanuvchi), qolgani alfavit bo'yicha.
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
