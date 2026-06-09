// ─────────────────────────────────────────────────────────────────────
// SocialSignInService — Google va Apple native flow wrapper
// ─────────────────────────────────────────────────────────────────────
//
// Bu service faqat **platforma SDK** bilan ishlaydi:
//   - Google: `google_sign_in` (Android/iOS/web)
//   - Apple:  `sign_in_with_apple` (iOS/macOS nativ, Android/web OAuth)
//
// Vazifa: ID token + (Apple uchun) ism olib qaytarish.
// Token'ni backend'ga yuborish — BackendAuthRepository'da.

// ignore_for_file: public_member_api_docs

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

class SocialSignInService {
  /// Google paketi platforma'ga qarab REVERSED_CLIENT_ID/SHA-1 orqali
  /// avtomatik client ID'ni topadi. Web uchun `web/index.html`'da
  /// `<meta name="google-signin-client_id" content="...">` kerak.
  /// Backend `aud`'ni shu client ID bo'yicha tekshiradi.
  final GoogleSignIn _google =
      GoogleSignIn(scopes: <String>['email', 'profile']);

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
