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

import 'package:dio/dio.dart';
import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// login.html FlutterAuth callback'idan kelgan JSON'ni saqlaydi.
  /// Tokens secure storage'ga, user obyekti caller'ga qaytariladi.
  Future<AuthUser> saveSession(AuthSession session) async {
    await _tokenStorage.saveTokens(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
    );
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

  /// Joriy user profilini Backend'dan oladi. Tokens kerak.
  /// 401 holatida DioClient interceptor refresh chaqiradi.
  Future<AuthUser?> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      final data = response.data;
      if (data == null) return null;
      return AuthUser.fromJson(data);
    } on DioException {
      return null;
    }
  }

  /// Logout — tokens'ni o'chiradi. (Backend session'i JWT stateless,
  /// server-side revoke kerak bo'lsa keyinroq /api/auth/logout qo'shiladi.)
  Future<void> logout() async {
    await _tokenStorage.clear();
  }

  /// Splash/startup tekshiruvi — refresh token bormi?
  Future<bool> hasSession() => _tokenStorage.hasValidSession();
}
