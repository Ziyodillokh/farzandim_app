// ─────────────────────────────────────────────────────────────────────
// AnonAuthRepository — Anonymous Firebase Auth wrapper
// ─────────────────────────────────────────────────────────────────────
//
// Bola ilova ochganda email/parol kiritmasdan UID oladi. Bu UID
// pairing oqimida Firestore'ga yoziladi (`users/{parent}/children/{child}.
// linkedDeviceUid`) — keyin barcha bola so'rovlari shu UID bilan bog'liq.
//
// Anonymous Auth — Firebase Console'da Sign-in method tab'da yoqilishi
// shart. Yoqilmagan bo'lsa `signInAnonymously()` xato beradi:
// "auth/operation-not-allowed".

import 'package:firebase_auth/firebase_auth.dart';

class AnonAuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Auth state stream — kim kirgan/chiqqanini real vaqtda kuzatadi.
  ///
  /// `Stream<User?>` — null bo'lsa kirilmagan, `User` bo'lsa kirilgan.
  /// `Riverpod`'da `StreamProvider` bilan ishlatiladi — UI auto-update.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get uid => _auth.currentUser?.uid;

  /// Anonymous sign-in.
  ///
  /// Agar foydalanuvchi allaqachon kirgan bo'lsa — qaytadan kirmaydi,
  /// mavjud `User`'ni qaytaradi (idempotent).
  ///
  /// Xato bo'lsa — `Exception` tashlaydi (Pairing flow ushlaydi).
  Future<User> signInAnonymously() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser!;
    }

    try {
      final credential = await _auth.signInAnonymously();
      if (credential.user == null) {
        throw Exception('Anonymous sign in failed');
      }
      return credential.user!;
    } catch (e) {
      throw Exception('Auth xatosi: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
