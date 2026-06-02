import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_token_storage.dart';

const _kAccess = 'farzandim.admin.access';
const _kRefresh = 'farzandim.admin.refresh';

Future<SecureTokenStorage> createSecureTokenStorage() async =>
    IoSecureTokenStorage(const FlutterSecureStorage());

final class IoSecureTokenStorage implements SecureTokenStorage {
  IoSecureTokenStorage(this._sec);

  final FlutterSecureStorage _sec;

  @override
  Future<String?> readAccessToken() => _sec.read(key: _kAccess);

  @override
  Future<String?> readRefreshToken() => _sec.read(key: _kRefresh);

  @override
  Future<void> writeAccessToken(String token) => _sec.write(key: _kAccess, value: token);

  @override
  Future<void> writeRefreshToken(String token) => _sec.write(key: _kRefresh, value: token);

  @override
  Future<void> clearRefreshToken() => _sec.delete(key: _kRefresh);

  @override
  Future<void> clearAll() async {
    await _sec.delete(key: _kAccess);
    await _sec.delete(key: _kRefresh);
  }
}
