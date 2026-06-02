/// Platform-agnostic access + refresh token persistence.
abstract interface class SecureTokenStorage {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> writeAccessToken(String token);

  Future<void> writeRefreshToken(String token);

  Future<void> clearRefreshToken();

  Future<void> clearAll();
}
