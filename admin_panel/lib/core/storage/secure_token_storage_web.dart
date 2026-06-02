import 'package:web/web.dart' as web;

import '../util/jwt_clock.dart';
import 'secure_token_storage.dart';

const _ns = 'farzandim.admin.v1.';
const _kAccess = '${_ns}access';

// H7 — refresh token endi brauzerda HttpOnly cookie sifatida saqlanadi
// (JavaScript, demak XSS ham, uni o'qiy olmaydi). localStorage'da faqat
// "sessiya bor" bayrog'i turadi — bu maxfiy ma'lumot emas.
const _kSession = '${_ns}session';
const _kLegacyRefresh = '${_ns}refresh';

Future<SecureTokenStorage> createSecureTokenStorage() async {
  // Migratsiya — eski versiyada localStorage'da turgan haqiqiy refresh
  // token'ni o'chiramiz (endi u faqat HttpOnly cookie'da bo'lishi kerak).
  web.window.localStorage.removeItem(_kLegacyRefresh);
  return WebSecureTokenStorage();
}

final class WebSecureTokenStorage implements SecureTokenStorage {
  web.Storage get _ls => web.window.localStorage;

  @override
  Future<String?> readAccessToken() async {
    final t = _ls.getItem(_kAccess);
    if (t == null || t.isEmpty) {
      return null;
    }
    if (isJwtExpired(t)) {
      _ls.removeItem(_kAccess);
      return null;
    }
    return t;
  }

  /// Refresh token HttpOnly cookie'da — bu yerda faqat sessiya bayrog'i.
  /// Sessiya aktiv bo'lsa `'cookie'` (bo'sh bo'lmagan belgi) qaytadi —
  /// bu HAQIQIY token EMAS, shunchaki "refresh sessiyasi mavjud" signali.
  @override
  Future<String?> readRefreshToken() async =>
      _ls.getItem(_kSession) == '1' ? 'cookie' : null;

  @override
  Future<void> writeAccessToken(String token) async {
    _ls.setItem(_kAccess, token);
  }

  /// `token` qiymati e'tiborga olinmaydi — haqiqiy refresh token serverda
  /// HttpOnly cookie'ga yoziladi. Bu yerda faqat sessiya bayrog'i o'rnatiladi.
  @override
  Future<void> writeRefreshToken(String token) async {
    _ls.setItem(_kSession, '1');
  }

  @override
  Future<void> clearRefreshToken() async {
    _ls.removeItem(_kSession);
  }

  @override
  Future<void> clearAll() async {
    _ls.removeItem(_kAccess);
    _ls.removeItem(_kSession);
    _ls.removeItem(_kLegacyRefresh);
  }
}
