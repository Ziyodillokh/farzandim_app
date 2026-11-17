// ─────────────────────────────────────────────────────────────────────
// ChildLogin — bolaning login qoidasi (backend bilan bir xil)
// ─────────────────────────────────────────────────────────────────────
//
// Backend: `^[a-z][a-z0-9._]{3,23}$` (4–24 belgi, kichik lotin harfidan
// boshlanadi; harf, raqam, nuqta va pastki chiziq). Backend loginni kichik
// harfda saqlaydi — kiritilgan matn avval kichik harfga o'tkaziladi.
// Foydalanuvchiga qaysi qoida buzilgani aytiladi (`ChildLoginIssue`).

/// Login qoidasi buzilgan holat; [messageKey] — tarjima kaliti.
enum ChildLoginIssue {
  tooShort('childCredentials.login.tooShort'),
  tooLong('childCredentials.login.tooLong'),
  badStart('childCredentials.login.badStart'),
  badChars('childCredentials.login.badChars');

  const ChildLoginIssue(this.messageKey);

  final String messageKey;
}

/// Bola logini bilan ishlash (normallashtirish va tekshirish).
abstract final class ChildLogin {
  static const int minLength = 4;
  static const int maxLength = 24;

  /// Backend naqshi — yagona haqiqat manbai.
  static final RegExp pattern = RegExp(r'^[a-z][a-z0-9._]{3,23}$');

  static final RegExp _firstChar = RegExp('^[a-z]');
  static final RegExp _allowedChars = RegExp(r'^[a-z0-9._]*$');

  /// Chetdagi bo'shliqlar olinadi, kichik harfga o'tkaziladi.
  static String normalize(String raw) => raw.trim().toLowerCase();

  /// Normallashtirilgan login backend naqshiga mosmi.
  static bool isValid(String raw) => pattern.hasMatch(normalize(raw));

  /// Qoida buzilgan bo'lsa — qaysi biri (formatdagi xato avval, so'ng
  /// uzunlik); to'g'ri bo'lsa `null`. Bo'sh matn `tooShort`: "login
  /// berilmagan"ni chaqiruvchi o'zi alohida hal qiladi.
  static ChildLoginIssue? validate(String raw) {
    final login = normalize(raw);
    if (login.isEmpty) return ChildLoginIssue.tooShort;
    if (!_firstChar.hasMatch(login)) return ChildLoginIssue.badStart;
    if (!_allowedChars.hasMatch(login)) return ChildLoginIssue.badChars;
    if (login.length < minLength) return ChildLoginIssue.tooShort;
    if (login.length > maxLength) return ChildLoginIssue.tooLong;
    return null;
  }
}
