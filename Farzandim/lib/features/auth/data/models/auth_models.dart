// Backend auth API DTO'lari. Freezed/json_serializable ishlatmaymiz —
// JSON qo'lda parse qilinadi, oddiy va aniq.

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

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

/// Auth javoblaridagi `user` obyekti. Backend nomlari factory'da moslanadi
/// (`name` → `displayName`, `avatarUrl` → `photoUrl`), `role` esa Flutter
/// ichida har doim lowercase saqlanadi.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.telegramId,
    this.language,
    this.phone,
    this.email,
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
      displayName:
          (json['name'] as String?) ?? (json['displayName'] as String?),
      photoUrl: (json['avatarUrl'] as String?) ?? (json['photoUrl'] as String?),
      // Backend telegramId String sifatida qaytaradi (BigInt overflow xavfi).
      telegramId: json['telegramId']?.toString(),
      language: json['language'] as String?,
      // GET /users/me — qaysi usul bilan ro'yxatdan o'tgani (phone/email).
      phone: (json['phone'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['phone'] as String).trim(),
      email: (json['email'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['email'] as String).trim(),
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

  /// Telefon raqami (phone bilan ro'yxatdan o'tgan bo'lsa). GET /users/me.
  final String? phone;

  /// Email (email bilan ro'yxatdan o'tgan bo'lsa). GET /users/me.
  final String? email;

  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';

  /// Lokal cache uchun (optimistik startup). `fromJson` o'qiy oladigan
  /// kalitlar bilan — `displayName`/`photoUrl` (round-trip xavfsiz).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'role': role,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'telegramId': telegramId,
    'language': language,
    'phone': phone,
    'email': email,
  };
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
