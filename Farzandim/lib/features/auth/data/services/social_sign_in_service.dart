// Google/Apple native sign-in wrapper — faqat ID token (Apple'da ism ham)
// olib qaytaradi; token'ni backend'ga yuborish BackendAuthRepository ishi.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Foydalanuvchi modal/popup'ni bekor qilganini xato sifatida emas, jim
/// signal sifatida ko'tarib chiqaramiz — UI bunga toast ko'rsatmaydi.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
  @override
  String toString() => 'SocialSignInCancelled';
}

/// Native SDK'dan kelgan ma'lumotlar — backend'ga shu yuboriladi.
class GoogleSignInResult {
  const GoogleSignInResult({required this.idToken});
  final String idToken;
}

class AppleSignInResult {
  const AppleSignInResult({required this.idToken, this.fullName});
  final String idToken;
  final String? fullName;
}

final socialSignInServiceProvider = Provider<SocialSignInService>((ref) {
  return SocialSignInService();
});

/// Google **Web Client ID** — Android/iOS'da `serverClientId` sifatida
/// ishlatiladi. Google Sign-In idToken'ni SHU audience bilan qaytaradi va
/// backend (`GOOGLE_CLIENT_IDS`) shuni tekshiradi. BUSIZ Android'da idToken
/// `null` keladi ("idToken bo'sh" xatosi). Bu SIR EMAS — ommaviy OAuth
/// identifikatori. Dart-define (`GOOGLE_SERVER_CLIENT_ID`) bilan almashtirsa
/// bo'ladi. Web'da ishlatilmaydi (web/index.html meta tag orqali).
const String _googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      // "Parvoz" Google Cloud loyihasining Web Client ID'si (backend
      // GOOGLE_CLIENT_IDS bilan bir xil bo'lishi shart).
      '931495868029-b7keq7og9afennh7h3smfaunlf34tsuh'
      '.apps.googleusercontent.com',
);

class SocialSignInService {
  /// Android: OAuth client (paket nomi + SHA-1) Play Services orqali avtomatik
  /// topiladi; idToken esa `serverClientId` (Web Client ID) bilan keladi.
  /// Web: `web/index.html`'dagi `<meta name="google-signin-client_id">` tag.
  /// Backend `aud`'ni shu client ID bo'yicha tekshiradi.
  final GoogleSignIn _google = GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    // Web'da serverClientId qo'llanmaydi (google_sign_in_web meta tag'dan
    // oladi) — shuning uchun faqat mobil platformalarda beramiz.
    serverClientId: kIsWeb ? null : _googleServerClientId,
  );

  /// Web dialog oqimi uchun plugin instansiyasi (renderButton + stream).
  GoogleSignIn get google => _google;

  /// Google sign-in dialog'ini ochadi.
  /// Bekor qilinsa — [SocialSignInCancelled] tashlaydi.
  Future<GoogleSignInResult> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) {
      throw const SocialSignInCancelled();
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception("Google idToken bo'sh — client ID sozlamasi yo'q?");
    }
    return GoogleSignInResult(idToken: idToken);
  }

  /// Apple Sign In oynasini ochadi.
  /// Android va web'da `webAuthenticationOptions` bilan OAuth redirect
  /// ishlatadi — `APPLE_SERVICE_ID` va `redirectUri` Apple Developer'da
  /// ro'yxatdan o'tgan bo'lishi kerak.
  /// Bekor qilinsa — [SocialSignInCancelled] tashlaydi.
  Future<AppleSignInResult> signInWithApple({
    String? serviceId,
    String? redirectUri,
  }) async {
    final isAppleNative = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: isAppleNative
            ? null
            : (serviceId == null || redirectUri == null)
            ? null
            : WebAuthenticationOptions(
                clientId: serviceId,
                redirectUri: Uri.parse(redirectUri),
              ),
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception("Apple identityToken bo'sh");
      }

      final names = <String>[
        if (credential.givenName != null && credential.givenName!.isNotEmpty)
          credential.givenName!,
        if (credential.familyName != null && credential.familyName!.isNotEmpty)
          credential.familyName!,
      ];
      return AppleSignInResult(
        idToken: idToken,
        fullName: names.isEmpty ? null : names.join(' '),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
  }
}
