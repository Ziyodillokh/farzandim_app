import 'package:flutter/foundation.dart';

import '../util/jwt_clock.dart';
import '../storage/secure_token_storage.dart';

/// Why the session was cleared (drives UX: dialog only for [sessionExpired]).
enum SessionClearCause {
  userLogout,
  sessionExpired,
  forcedAuthFailure,
}

/// In-memory auth + persistent storage. Call [bindStorage] then [hydrate] at startup.
class AdminSession {
  AdminSession._();

  static SecureTokenStorage? _storage;
  static String? _accessToken;
  static String? _refreshToken;
  static String? _authFingerprint;

  /// Drives [GoRouter] redirect refresh when auth changes.
  static final ValueNotifier<int> authRevision = ValueNotifier<int>(0);

  /// Bumped when [applyStaffProfile] changes (sidebar / permission-gated UI).
  static final ValueNotifier<int> staffProfileTick = ValueNotifier<int>(0);

  /// Incremented when [clear] is called with [SessionClearCause.sessionExpired] (refresh failed).
  static final ValueNotifier<int> sessionExpiredTick = ValueNotifier<int>(0);

  static String? _staffRole;
  static bool _staffFullAccess = false;
  static List<String> _staffPermissions = const [];

  static String? get staffRole => _staffRole;

  /// `ADMIN` (full) — also true when [isFullAccess] from API.
  static bool get isStaffAdmin => _staffRole == 'ADMIN' || _staffFullAccess;

  static bool canPermission(String key) {
    if (isStaffAdmin) {
      return true;
    }
    return _staffPermissions.contains(key);
  }

  static void applyStaffProfile(Map<String, dynamic> json) {
    _staffRole = json['role'] as String?;
    _staffFullAccess = json['isFullAccess'] == true;
    final p = json['permissions'];
    if (p is List) {
      _staffPermissions = p.map((e) => '$e').toList();
    } else {
      _staffPermissions = const [];
    }
    staffProfileTick.value = staffProfileTick.value + 1;
  }

  static void _clearStaff() {
    _staffRole = null;
    _staffFullAccess = false;
    _staffPermissions = const [];
    staffProfileTick.value = staffProfileTick.value + 1;
  }

  static void bindStorage(SecureTokenStorage storage) {
    _storage = storage;
  }

  static Future<void> hydrate() async {
    final s = _storage;
    if (s == null) {
      return;
    }
    final nextAccess = await s.readAccessToken();
    final nextRefresh = await s.readRefreshToken();
    _accessToken = nextAccess;
    _refreshToken = nextRefresh;
    _maybeBumpAuthRevision();
  }

  static String? get token => _accessToken;

  static String? get refreshToken => _refreshToken;

  static bool get hasRefreshToken =>
      _refreshToken != null && _refreshToken!.isNotEmpty;

  /// Valid session: usable access JWT, or expired access with refresh to recover.
  static bool get isAuthenticated {
    final t = _accessToken;
    if (t != null && t.isNotEmpty) {
      if (isJwtExpired(t)) {
        return hasRefreshToken;
      }
      return true;
    }
    return false;
  }

  /// Proactive refresh when access JWT is near expiry and refresh exists.
  static bool get needsProactiveRefresh {
    final t = _accessToken;
    if (t == null || t.isEmpty || !hasRefreshToken) {
      return false;
    }
    if (readJwtExpSeconds(t) == null) {
      return false;
    }
    return shouldRefreshBeforeRequest(t);
  }

  static Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final s = _storage;
    if (s == null) {
      return;
    }
    await s.writeAccessToken(accessToken);
    _accessToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await s.writeRefreshToken(refreshToken);
      _refreshToken = refreshToken;
    } else {
      await s.clearRefreshToken();
      _refreshToken = null;
    }
    _maybeBumpAuthRevision();
  }

  static Future<void> setAccessToken(String accessToken) async {
    await setTokens(accessToken: accessToken);
  }

  static Future<void> clear({SessionClearCause cause = SessionClearCause.userLogout}) async {
    final s = _storage;
    if (s != null) {
      await s.clearAll();
    }
    _accessToken = null;
    _refreshToken = null;
    _clearStaff();
    if (cause == SessionClearCause.sessionExpired) {
      sessionExpiredTick.value = sessionExpiredTick.value + 1;
    }
    _maybeBumpAuthRevision();
  }

  static void _maybeBumpAuthRevision() {
    final fp = '${_accessToken ?? ''}|||${_refreshToken ?? ''}';
    if (fp == _authFingerprint) {
      return;
    }
    _authFingerprint = fp;
    authRevision.value = authRevision.value + 1;
  }
}
