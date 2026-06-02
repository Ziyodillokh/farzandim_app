import 'package:admin_panel_flutter/core/storage/secure_token_storage.dart';

/// In-memory [SecureTokenStorage] for unit/widget tests (no platform channels).
final class MemoryTokenStorage implements SecureTokenStorage {
  MemoryTokenStorage({String? accessToken, String? refreshToken})
      : _access = accessToken,
        _refresh = refreshToken;

  String? _access;
  String? _refresh;

  @override
  Future<void> clearAll() async {
    _access = null;
    _refresh = null;
  }

  @override
  Future<void> clearRefreshToken() async {
    _refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> writeAccessToken(String token) async {
    _access = token;
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    _refresh = token;
  }
}
