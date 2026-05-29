// ─────────────────────────────────────────────────────────────────────
// TokenStorage — JWT access/refresh tokenlarini xavfsiz saqlash
// ─────────────────────────────────────────────────────────────────────
//
// Backend POST /api/auth/child-pair familyCode → JWT pair beradi:
//   - accessToken: 15 daqiqa
//   - refreshToken: 30 kun
//
// Android KeyStore + iOS Keychain — SharedPreferences emas (secrets).

// ignore_for_file: public_member_api_docs

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'jwt_access_token';
  static const _kRefreshToken = 'jwt_refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> updateAccessToken(String newAccessToken) async {
    await _storage.write(key: _kAccessToken, value: newAccessToken);
  }

  Future<void> updateRefreshToken(String newRefreshToken) async {
    await _storage.write(key: _kRefreshToken, value: newRefreshToken);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
    ]);
  }

  Future<bool> hasValidSession() async {
    final refresh = await readRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }
}
