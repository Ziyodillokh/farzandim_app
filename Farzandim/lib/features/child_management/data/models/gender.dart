// Bola jinsi uchun enum. String o'rniga enum tanlangan: 'male' dagi tipo
// kompilatsiyada ushlanmaydi, enum bilan esa switch hamma variantni qamraydi.

/// Bola jinsi.
enum Gender { male, female }

extension GenderX on Gender {
  /// UI'da ko'rsatish uchun o'zbekcha yorliq. Hozircha lokalizatsiya
  /// qilinmagan — kerak bo'lsa `'gender.male'.tr()` kabi kalitga o'tkaziladi.
  String get label {
    switch (this) {
      case Gender.male:
        return "O'g'il";
      case Gender.female:
        return 'Qiz';
    }
  }
}
