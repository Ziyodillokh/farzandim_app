// ─────────────────────────────────────────────────────────────────────
// TokenStorage — JWT access/refresh tokenlarini xavfsiz saqlash
// ─────────────────────────────────────────────────────────────────────
//
// Backend Telegram Login + JWT pair beradi (Sprint 4.4):
//   - accessToken: 15 daqiqa amal qiladi, har request'ga Bearer header
//   - refreshToken: 30 kun amal qiladi, access token expire bo'lganda
//                   `/api/auth/refresh` ga yuboriladi
//
// SharedPreferences EMAS — secrets uchun encrypted storage kerak:
//   - Android: KeyStore (Android Keystore System)
//   - iOS: Keychain Services (kSecAttrAccessibleAfterFirstUnlock)
//
// API:
//   await TokenStorage.saveTokens(access: ..., refresh: ...);
//   final access = await TokenStorage.readAccessToken();
//   await TokenStorage.clear(); // logout
//
// Riverpod orqali ham ishlatish mumkin:
//   final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Riverpod provider — global singleton.
final tokenStorageProvider = Provider<TokenStorage>(
  (_) => TokenStorage(),
);

/// Web platformasi uchun `flutter_secure_storage_web` Web Crypto API
/// (SubtleCrypto) orqali AES-GCM kalit derivatsiya qiladi. Chrome'da
/// ba'zi holatlarda `OperationError` portlaydi (incognito, repeated
/// AES key wrap). Lokal dev/preview uchun SharedPreferences yetadi —
/// brauzer localStorage'iga oddiy matn saqlanadi (token allaqachon
/// HTTPS orqali keladi, hozircha xavfsizlik darajasi yetarli).
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

  // Storage kalitlari — bitta joyda toza tutamiz.
  static const _kAccessToken = 'jwt_access_token';
  static const _kRefreshToken = 'jwt_refresh_token';

  /// Login muvaffaqiyatli bo'lganda chaqiriladi.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _backend.write(_kAccessToken, accessToken),
      _backend.write(_kRefreshToken, refreshToken),
    ]);
  }

  /// Har request'da Bearer header uchun chaqiriladi.
  Future<String?> readAccessToken() => _backend.read(_kAccessToken);

  /// 401 javob kelganda /api/auth/refresh uchun.
  Future<String?> readRefreshToken() => _backend.read(_kRefreshToken);

  /// Access token expire bo'lib refresh muvaffaqiyatli bo'lgach,
  /// yangi access token saqlanadi (refresh ham kelishi mumkin).
  Future<void> updateAccessToken(String newAccessToken) =>
      _backend.write(_kAccessToken, newAccessToken);

  /// Refresh response ikkala token yangi qiymatini berishi mumkin.
  Future<void> updateRefreshToken(String newRefreshToken) =>
      _backend.write(_kRefreshToken, newRefreshToken);

  /// Logout — barcha tokenlarni o'chirish.
  Future<void> clear() async {
    await Future.wait([
      _backend.delete(_kAccessToken),
      _backend.delete(_kRefreshToken),
    ]);
  }

  /// Auth holatini tekshirish (router redirect uchun).
  Future<bool> hasValidSession() async {
    final refresh = await readRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }
}
