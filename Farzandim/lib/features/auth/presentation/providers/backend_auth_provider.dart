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

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthAnonymous();
  }
}
