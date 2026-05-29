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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Riverpod provider — global singleton.
final tokenStorageProvider = Provider<TokenStorage>(
  (_) => TokenStorage(),
);

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  final FlutterSecureStorage _storage;

  // Storage kalitlari — bitta joyda toza tutamiz.
  static const _kAccessToken = 'jwt_access_token';
  static const _kRefreshToken = 'jwt_refresh_token';

  /// Login muvaffaqiyatli bo'lganda chaqiriladi.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  /// Har request'da Bearer header uchun chaqiriladi.
  Future<String?> readAccessToken() async {
    return _storage.read(key: _kAccessToken);
  }

  /// 401 javob kelganda /api/auth/refresh uchun.
  Future<String?> readRefreshToken() async {
    return _storage.read(key: _kRefreshToken);
  }

  /// Access token expire bo'lib refresh muvaffaqiyatli bo'lgach,
  /// yangi access token saqlanadi (refresh ham kelishi mumkin).
  Future<void> updateAccessToken(String newAccessToken) async {
    await _storage.write(key: _kAccessToken, value: newAccessToken);
  }

  /// Refresh response ikkala token yangi qiymatini berishi mumkin.
  Future<void> updateRefreshToken(String newRefreshToken) async {
    await _storage.write(key: _kRefreshToken, value: newRefreshToken);
  }

  /// Logout — barcha tokenlarni o'chirish.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
    ]);
  }

  /// Auth holatini tekshirish (router redirect uchun).
  Future<bool> hasValidSession() async {
    final refresh = await readRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }
}
