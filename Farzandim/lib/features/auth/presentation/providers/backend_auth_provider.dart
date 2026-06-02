// ─────────────────────────────────────────────────────────────────────
// BackendAuthProvider — Riverpod auth state (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Eski `authProvider` (Firebase) o'zicha qoladi — yangi Backend auth
// alohida. Migration tugagach eski olib tashlanadi.
//
// State machine:
//   unknown    → startup splash holati (token bor-yo'qligi tekshirilmoqda)
//   anonymous  → token yo'q / refresh fail
//   authenticated → tokens + user obyekti mavjud
//
// Loyihaning router'i shu state'ni ko'rib redirect qiladi:
//   anonymous  → /welcome
//   authenticated → /dashboard
//   unknown    → /splash (ko'rinish saqlash)

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:farzandim/features/auth/data/repositories/backend_auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class BackendAuthState {
  const BackendAuthState();
}

class AuthUnknown extends BackendAuthState {
  const AuthUnknown();
}

class AuthAnonymous extends BackendAuthState {
  const AuthAnonymous();
}

class AuthAuthenticated extends BackendAuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

class AuthError extends BackendAuthState {
  const AuthError(this.message);
  final String message;
}

final backendAuthProvider =
    StateNotifierProvider<BackendAuthNotifier, BackendAuthState>((ref) {
  return BackendAuthNotifier(
    repository: ref.watch(backendAuthRepositoryProvider),
  );
});

class BackendAuthNotifier extends StateNotifier<BackendAuthState> {
  BackendAuthNotifier({required BackendAuthRepository repository})
      : _repo = repository,
        super(const AuthUnknown()) {
    // Auto-bootstrap: app ochilganda saqlangan token tekshiriladi.
    // AuthUnknown → AuthAuthenticated yoki AuthAnonymous'ga o'tadi.
    bootstrap();
  }

  final BackendAuthRepository _repo;

  /// Startup'da chaqiriladi (SplashScreen). Tokens bor-yo'qligini
  /// tekshiradi va kerak bo'lsa /users/me chaqiradi.
  Future<void> bootstrap() async {
    final has = await _repo.hasSession();
    if (!has) {
      state = const AuthAnonymous();
      return;
    }

    final user = await _repo.me();
    if (user == null) {
      // Refresh ham fail — logout
      await _repo.logout();
      state = const AuthAnonymous();
      return;
    }

    state = AuthAuthenticated(user);
  }

  /// Login muvaffaqiyatli tugadi — tokens va user obyektini saqlaydi.
  /// JSON parsing screen'da bajariladi (cleaner separation).
  Future<void> onLoggedIn(AuthTokens tokens, AuthUser user) async {
    try {
      await _repo.saveSession(AuthSession(tokens: tokens, user: user));
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError('Login saqlashda xato: $e');
    }
  }

  /// Email/telefon + parol bilan kirish.
  /// `null` qaytsa — muvaffaqiyat (router dashboard'ga o'tkazadi).
  /// Aks holda — ko'rsatish uchun o'zbekcha xato xabari qaytaradi.
  Future<String?> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      final session = await _repo.login(
        identifier: identifier,
        password: password,
      );
      await _repo.saveSession(session);
      state = AuthAuthenticated(session.user);
      return null;
    } on DioException catch (e) {
      return _friendlyError(e, "Kirishda xatolik. Qaytadan urinib ko'ring.");
    } catch (_) {
      return 'Kutilmagan xatolik yuz berdi.';
    }
  }

  /// Email yoki telefon + parol bilan ro'yxatdan o'tish.
  /// `null` qaytsa — muvaffaqiyat. Aks holda — xato xabari.
  Future<String?> registerWithPassword({
    required String password,
    String? email,
    String? phone,
    String? name,
  }) async {
    try {
      final session = await _repo.register(
        email: email,
        phone: phone,
        password: password,
        name: name,
      );
      await _repo.saveSession(session);
      state = AuthAuthenticated(session.user);
      return null;
    } on DioException catch (e) {
      return _friendlyError(
        e,
        "Ro'yxatdan o'tishda xatolik. Qaytadan urinib ko'ring.",
      );
    } catch (_) {
      return 'Kutilmagan xatolik yuz berdi.';
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthAnonymous();
  }

  /// Backend xato javobidan o'zbekcha xabar ajratib oladi.
  /// NestJS exception filter `{ message: string | string[] }` qaytaradi.
  String _friendlyError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Internet aloqasi yo'q. Ulanishni tekshiring.";
    }
    return fallback;
  }
}
