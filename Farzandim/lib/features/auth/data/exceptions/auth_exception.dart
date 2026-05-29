/// Foydalanuvchiga ko'rsatish uchun mo'ljallangan auth xatosi.
///
/// `AuthRepository._mapFirebaseAuthError` `FirebaseAuthException`'ni
/// shu klassga aylantiradi va xabarni o'zbekchaga tarjima qiladi.
/// SnackBar va dialog'larda `e.toString()` orqali to'g'ridan-to'g'ri
/// ko'rsatiladi.
class AuthException implements Exception {
  /// `AuthException` konstruktor.
  const AuthException(this.message, {this.code});

  /// Foydalanuvchiga ko'rinadigan xabar (o'zbekcha).
  final String message;

  /// Asl Firebase xato kodi (`email-already-in-use`, va h.k.) —
  /// debug uchun saqlanadi, UI'da ko'rsatilmaydi.
  final String? code;

  @override
  String toString() => message;
}
