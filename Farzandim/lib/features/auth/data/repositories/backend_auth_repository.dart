// ─────────────────────────────────────────────────────────────────────
// BackendAuthRepository — Backend REST auth (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firebase auth_repository.dart o'zicha qoladi (Firebase Auth phone OTP)
// — yangi Backend Telegram auth alohida implementatsiya. Migration tugagach
// eski olib tashlanadi.
//
// 3 ta operatsiya:
//   1. saveSession(session)  — login.html callback'idan kelgan AuthSession
//                              tokens'ni storage'ga yozadi, user qaytaradi
//   2. refresh()             — accessToken expire bo'lganda; Dio refresh
//                              interceptor allaqachon bu chaqiradi
//   3. logout()              — tokens'ni o'chiradi
//   4. me()                  — joriy user profile'i (GET /api/users/me)
//
// Login flow:
//   TelegramLoginScreen WebView → login.html → FlutterAuth.postMessage(JSON)
//     → AuthProvider.handleSession(json) → repo.saveSession(session)
//     → router redirect '/dashboard'

// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/device/device_meta.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final backendAuthRepositoryProvider = Provider<BackendAuthRepository>((ref) {
  return BackendAuthRepository(
    dio: ref.watch(dioClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class BackendAuthRepository {
  BackendAuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Optimistik startup uchun oxirgi user profilini lokal saqlash kaliti.
  /// Token emas — maxfiy emas, shuning uchun SharedPreferences yetarli.
  static const _cachedUserKey = 'auth.cached_user.v1';

  /// Email yoki telefon + parol bilan ro'yxatdan o'tish.
  /// Backend: POST /api/auth/register → { accessToken, refreshToken, user }.
  /// Kamida `email` yoki `phone` berilishi shart.
  Future<AuthSession> register({
    required String password,
    String? email,
    String? phone,
    String? name,
  }) async {
    final device = await currentDeviceMeta();
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: <String, dynamic>{
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
        ...device.toJson(),
      },
    );
    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Google ID token bilan login/register.
  /// Backend: POST /api/auth/google → { accessToken, refreshToken, user }.
  /// `idToken` — `google_sign_in` paketidan kelgan `idToken` (JWT).
  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final device = await currentDeviceMeta();
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/google',
      data: <String, dynamic>{
        'idToken': idToken,
        ...device.toJson(),
      },
    );
    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Apple ID token bilan login/register.
  /// Backend: POST /api/auth/apple → { accessToken, refreshToken, user }.
  /// `idToken` — `sign_in_with_apple` paketidan kelgan `identityToken`.
  /// `name` — birinchi loginda Apple beradi (`AuthorizationCredentialAppleID
  /// .givenName + familyName`); keyingi safar kelmaydi.
  Future<AuthSession> loginWithApple({
    required String idToken,
    String? name,
  }) async {
    final device = await currentDeviceMeta();
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/apple',
      data: <String, dynamic>{
        'idToken': idToken,
        if (name != null && name.isNotEmpty) 'name': name,
        ...device.toJson(),
      },
    );
    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Email yoki telefon + parol bilan kirish.
  /// Backend: POST /api/auth/login → { accessToken, refreshToken, user }.
  /// `identifier` — email manzili yoki +998 telefon raqami.
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final device = await currentDeviceMeta();
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: <String, dynamic>{
        'identifier': identifier,
        'password': password,
        ...device.toJson(),
      },
    );
    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  /// login.html FlutterAuth callback'idan kelgan JSON'ni saqlaydi.
  /// Tokens secure storage'ga, user obyekti caller'ga qaytariladi.
  Future<AuthUser> saveSession(AuthSession session) async {
    await _tokenStorage.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );
    await _cacheUser(session.user);
    return session.user;
  }

  /// JSON string'dan AuthSession parse + saqlash (qulay wrapper).
  /// Login WebView callback'i shu metod chaqiradi.
  Future<AuthUser> handleCallbackJson(Map<String, dynamic> json) async {
    final session = AuthSession.fromJson(json);
    return saveSession(session);
  }

  /// Manual refresh — odatda DioClient interceptor'i avtomatik qiladi,
  /// faqat splash/startup'da explicit kerak bo'lsa.
  Future<bool> refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data == null) return false;

      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null) return false;

      await _tokenStorage.updateAccessToken(newAccess);
      if (newRefresh != null) {
        await _tokenStorage.updateRefreshToken(newRefresh);
      }
      return true;
    } on DioException {
      return false;
    }
  }

  /// Joriy user profilini Backend'dan oladi va lokal cache'ga yozadi.
  ///
  /// **Xatoni YUTMAYDI** (bootstrap tarmoq xatosi va auth xatosini ajrata
  /// olishi uchun):
  ///   - Muvaffaqiyat → AuthUser (token amal qiladi, cache yangilanadi).
  ///   - 401 (DioClient interceptor refresh ham fail) → DioException(401)
  ///     tashlaydi → token o'lik → logout.
  ///   - Tarmoq xatosi (offline) → DioException(connectionError) tashlaydi →
  ///     caller optimistik holatni saqlashi mumkin.
  Future<AuthUser?> verifySession() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    final data = response.data;
    if (data == null) return null;
    final user = AuthUser.fromJson(data);
    await _cacheUser(user);
    return user;
  }

  /// Oxirgi muvaffaqiyatli user profilini lokal saqlaydi (optimistik startup).
  Future<void> _cacheUser(AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {
      // Cache best-effort — xato bo'lsa jim o'tamiz.
    }
  }

  /// Lokal saqlangan user (tarmoqsiz). Optimistik startup uchun — `/users/me`
  /// javobini kutmasdan darhol "kirgan" holatga o'tish imkonini beradi.
  Future<AuthUser?> cachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return AuthUser.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Logout — backend'da joriy sessiyani tugatadi va local tokens'ni o'chiradi.
  /// Backend revoke best-effort: tarmoq yo'q / token muddati o'tgan bo'lsa
  /// ham local logout bajariladi.
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Offline / token expired — local tozalash baribir davom etadi.
    }
    await _tokenStorage.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserKey);
    } catch (_) {
      // best-effort
    }
  }

  /// Splash/startup tekshiruvi — refresh token bormi?
  Future<bool> hasSession() => _tokenStorage.hasValidSession();
}
