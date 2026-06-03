// ─────────────────────────────────────────────────────────────────────
// TokenStorage — JWT access/refresh tokenlarini xavfsiz saqlash
// ─────────────────────────────────────────────────────────────────────
//
// Backend POST /api/auth/child-pair familyCode → JWT pair beradi:
//   - accessToken: 15 daqiqa
//   - refreshToken: 30 kun
//
// Android KeyStore + iOS Keychain — SharedPreferences emas (secrets).
// Web preview/dev — SharedPreferences fallback (flutter_secure_storage_web
// SubtleCrypto'da OperationError beradi).

// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

abstract class _Backend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class _SecureStorageBackend implements _Backend {
  _SecureStorageBackend()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _SharedPrefsBackend implements _Backend {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }
}

class TokenStorage {
  TokenStorage({_Backend? backend})
      : _backend = backend ??
            (kIsWeb ? _SharedPrefsBackend() : _SecureStorageBackend());

  final _Backend _backend;

  static const _kAccessToken = 'jwt_access_token';
  static const _kRefreshToken = 'jwt_refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _backend.write(_kAccessToken, accessToken),
      _backend.write(_kRefreshToken, refreshToken),
    ]);
  }

  Future<String?> readAccessToken() => _backend.read(_kAccessToken);
  Future<String?> readRefreshToken() => _backend.read(_kRefreshToken);

  Future<void> updateAccessToken(String newAccessToken) =>
      _backend.write(_kAccessToken, newAccessToken);

  Future<void> updateRefreshToken(String newRefreshToken) =>
      _backend.write(_kRefreshToken, newRefreshToken);

  Future<void> clear() async {
    await Future.wait([
      _backend.delete(_kAccessToken),
      _backend.delete(_kRefreshToken),
    ]);
  }

  Future<bool> hasValidSession() async {
    final refresh = await readRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }
}
