// ─────────────────────────────────────────────────────────────────────
// AuthModels — Backend Auth API DTO'lar (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST /api/auth/telegram
//     body:     { id, first_name, last_name?, username?, photo_url?,
//                 auth_date, hash }
//     response: { accessToken, refreshToken, user: AuthUser }
//
//   POST /api/auth/refresh
//     body:     { refreshToken }
//     response: { accessToken, refreshToken }
//
// Flutter side login.html'dan JSON oladi (FlutterAuth JavascriptChannel):
//   { accessToken, refreshToken, user: { id, role, ... } }
//
// Bu fayl DTO'lar (data transfer objects) — backend JSON ↔ Dart object.
// Freezed/json_serializable ishlatmaymiz (oddiy va aniq), qo'lda parse.

// ignore_for_file: public_member_api_docs

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'] as String?;
    final refresh = json['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw const FormatException("AuthTokens: accessToken/refreshToken yo'q");
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  final String accessToken;
  final String refreshToken;
}

/// User profile minimal — login.html callback'dagi `user` obyekti.
///
/// Backend kontrakt (POST /api/auth/telegram response.user):
/// ```json
/// {
///   "id": "uuid",
///   "name": "Ahmad",
///   "role": "PARENT" | "CHILD",
///   "avatarUrl": "https://...",
///   "telegramId": "123456",
///   "language": "uz" | "ru" | "en"
/// }
/// ```
///
/// Flutter ichida `role` lowercase saqlanadi (case-fold), backend nom
/// mapping ham factory'da bajariladi (`name` → `displayName`,
/// `avatarUrl` → `photoUrl`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.telegramId,
    this.language,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final rawRole = json['role'] as String?;
    if (id == null || rawRole == null) {
      throw const FormatException("AuthUser: id/role yo'q");
    }
    return AuthUser(
      id: id,
      // Backend `PARENT`/`CHILD` (uppercase enum) → lowercase normalize.
      role: rawRole.toLowerCase(),
      // Backend nom mapping: name → displayName, avatarUrl → photoUrl
      displayName: (json['name'] as String?) ??
          (json['displayName'] as String?),
      photoUrl: (json['avatarUrl'] as String?) ??
          (json['photoUrl'] as String?),
      // Backend telegramId String sifatida qaytaradi (BigInt overflow xavfi).
      telegramId: json['telegramId']?.toString(),
      language: json['language'] as String?,
    );
  }

  /// Backend UUID (users.id).
  final String id;

  /// 'parent' | 'child' — Flutter ichida har doim lowercase.
  final String role;

  /// Foydalanuvchi ko'rsatadigan ism (Telegram first_name + last_name).
  final String? displayName;

  /// Telegram avatar URL.
  final String? photoUrl;

  /// Telegram numerik ID (String sifatida — JS Number precision xavfsiz).
  final String? telegramId;

  /// Foydalanuvchi tanlagan til: 'uz' | 'ru' | 'en'. Backend default 'uz'.
  final String? language;

  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';
}

/// `FlutterAuth.postMessage(JSON)` orqali login.html'dan keladi.
/// Tokens + user bir butun payload.
class AuthSession {
  const AuthSession({required this.tokens, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException("AuthSession: user obyekti yo'q");
    }
    return AuthSession(
      tokens: AuthTokens.fromJson(json),
      user: AuthUser.fromJson(userJson),
    );
  }

  final AuthTokens tokens;
  final AuthUser user;
}
