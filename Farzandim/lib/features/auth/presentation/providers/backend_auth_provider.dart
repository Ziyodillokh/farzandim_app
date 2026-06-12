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

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/core/cache/swr_cache.dart';
import 'package:farzandim/core/network/dio_client.dart' show onSessionExpired;
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:farzandim/features/auth/data/repositories/backend_auth_repository.dart';
import 'package:farzandim/features/auth/data/services/social_sign_in_service.dart';
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
    socialSignIn: ref.watch(socialSignInServiceProvider),
  );
});

class BackendAuthNotifier extends StateNotifier<BackendAuthState> {
  BackendAuthNotifier({
    required BackendAuthRepository repository,
    required SocialSignInService socialSignIn,
  })  : _repo = repository,
        _social = socialSignIn,
        super(const AuthUnknown()) {
    // Sessiya tugashi (refresh token 401/403 — tokenlar o'chirilgan) —
    // dio_client xabar beradi, biz darhol login holatiga o'tamiz (router
    // login ekraniga olib boradi). Busiz foydalanuvchi "zombi" qolardi.
    onSessionExpired = () {
      if (mounted && state is! AuthAnonymous) {
        state = const AuthAnonymous();
        // NET-07 xavfsizlik: sessiya tugadi — disk-kesh ham tozalanadi.
        unawaited(SwrCache.clearAll());
      }
    };
    // Auto-bootstrap: app ochilganda saqlangan token tekshiriladi.
    // AuthUnknown → AuthAuthenticated yoki AuthAnonymous'ga o'tadi.
    bootstrap();
  }

  final BackendAuthRepository _repo;
  final SocialSignInService _social;

  /// Startup'da chaqiriladi. Tokens bor-yo'qligini tekshiradi va saqlangan
  /// user bo'lsa OPTIMISTIK ravishda darhol "kirgan" holatga o'tadi.
  Future<void> bootstrap() async {
    final has = await _repo.hasSession();
    if (!has) {
      state = const AuthAnonymous();
      return;
    }

    // OPTIMISTIK RESTORE: saqlangan user bo'lsa `/users/me` tarmoq javobini
    // KUTMASDAN darhol AuthAuthenticated'ga o'tamiz. Router darhol dashboard'ga
    // boradi — avvalgi ~2s "login sahifa ko'rinib turib keyin kiradi" flash'i
    // yo'qoladi. Profil fonda tasdiqlanadi/yangilanadi.
    final cached = await _repo.cachedUser();
    if (cached != null) {
      state = AuthAuthenticated(cached);
    }

    try {
      final user = await _repo.verifySession();
      if (user != null) {
        state = AuthAuthenticated(user);
      } else if (cached == null) {
        state = const AuthAnonymous();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token o'lik (refresh ham muvaffaqiyatsiz) — chiqamiz.
        await _repo.logout();
        // NET-07 xavfsizlik: bu chiqish yo'lida ham kesh tozalanadi.
        await SwrCache.clearAll();
        state = const AuthAnonymous();
      } else if (cached == null) {
        // Tarmoq xatosi + cache yo'q — kira olmaymiz.
        state = const AuthAnonymous();
      }
      // else: tarmoq xatosi + cache bor → optimistik holat saqlanadi (offline
      //       bo'lsa ham dashboard ochiladi; haqiqiy 401 Dio interceptor'da).
    } catch (_) {
      if (cached == null) state = const AuthAnonymous();
    }
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

  /// Google bilan kirish/ro'yxatdan o'tish.
  /// `null` qaytsa — muvaffaqiyat (router dashboard'ga o'tkazadi).
  /// Foydalanuvchi modal'ni bekor qilsa ham `null` qaytadi (jim chiqamiz).
  /// Aks holda — UI'da ko'rsatish uchun o'zbekcha xato xabari.
  Future<String?> signInWithGoogle() async {
    try {
      final google = await _social.signInWithGoogle();
      final session = await _repo.loginWithGoogle(idToken: google.idToken);
      await _repo.saveSession(session);
      state = AuthAuthenticated(session.user);
      return null;
    } on SocialSignInCancelled {
      return null; // jim — foydalanuvchi o'zi yopdi
    } on DioException catch (e) {
      return _friendlyError(e, 'Google bilan kirishda xatolik.');
    } catch (e) {
      return "Google bilan kirib bo'lmadi: $e";
    }
  }

  /// Apple bilan kirish/ro'yxatdan o'tish.
  /// [serviceId] va [redirectUri] — Android/web OAuth flow uchun, iOS'da
  /// kerak emas (nativ).
  Future<String?> signInWithApple({
    String? serviceId,
    String? redirectUri,
  }) async {
    try {
      final apple = await _social.signInWithApple(
        serviceId: serviceId,
        redirectUri: redirectUri,
      );
      final session = await _repo.loginWithApple(
        idToken: apple.idToken,
        name: apple.fullName,
      );
      await _repo.saveSession(session);
      state = AuthAuthenticated(session.user);
      return null;
    } on SocialSignInCancelled {
      return null;
    } on DioException catch (e) {
      return _friendlyError(e, 'Apple bilan kirishda xatolik.');
    } catch (e) {
      return "Apple bilan kirib bo'lmadi: $e";
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    // NET-07 xavfsizlik: SWR disk-keshi tozalanadi — keyingi akkaunt
    // oldingisining bolalari/ma'lumotini KO'RMAYDI.
    await SwrCache.clearAll();
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
