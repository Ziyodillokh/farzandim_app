// Riverpod auth holati: unknown (startup, token tekshirilmoqda) → anonymous
// yoki authenticated. Router shu holatga qarab welcome/dashboard'ga
// yo'naltiradi.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/cache/swr_cache.dart';
import 'package:farzandim/core/network/dio_client.dart' show onSessionExpired;
import 'package:farzandim/core/network/friendly_error.dart';
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
  }) : _repo = repository,
       _social = socialSignIn,
       super(const AuthUnknown()) {
    // Sessiya tugashi (refresh token 401/403 — tokenlar o'chirilgan) —
    // dio_client xabar beradi, biz darhol login holatiga o'tamiz (router
    // login ekraniga olib boradi). Busiz foydalanuvchi "zombi" qolardi.
    onSessionExpired = () {
      if (mounted && state is! AuthAnonymous) {
        state = const AuthAnonymous();
        // Sessiya tugadi — xavfsizlik uchun disk-kesh ham tozalanadi.
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
  /// user bo'lsa optimistik ravishda darhol "kirgan" holatga o'tadi.
  Future<void> bootstrap() async {
    final has = await _repo.hasSession();
    if (!has) {
      state = const AuthAnonymous();
      return;
    }

    // Saqlangan user bo'lsa `/users/me` tarmoq javobini kutmasdan darhol
    // AuthAuthenticated'ga o'tamiz. Router darhol dashboard'ga boradi —
    // avvalgi ~2s "login sahifa ko'rinib turib keyin kiradi" flash'i
    // yo'qoladi. Profil fonda tasdiqlanadi/yangilanadi.
    final cached = await _repo.cachedUser();
    if (cached != null) {
      // Bu PARENT ilovasi — agar saqlangan token CHILD foydalanuvchiga tegishli
      // bo'lsa (masalan dev'da portlar almashib, child ilova shu origin'da
      // token qoldirgan bo'lsa), uni qabul qilmaymiz: barcha parent-only
      // endpoint'lar 403 berib, foydalanuvchi "Forbidden" holatda qolardi.
      if (!cached.isParent) {
        await _repo.logout();
        await SwrCache.clearAll();
        state = const AuthAnonymous();
        return;
      }
      state = AuthAuthenticated(cached);
    }

    try {
      final user = await _repo.verifySession();
      if (user != null) {
        // Server tasdiqlagan rol ham PARENT bo'lishi shart.
        if (!user.isParent) {
          await _repo.logout();
          await SwrCache.clearAll();
          state = const AuthAnonymous();
          return;
        }
        state = AuthAuthenticated(user);
      } else if (cached == null) {
        state = const AuthAnonymous();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token o'lik (refresh ham muvaffaqiyatsiz) — chiqamiz.
        await _repo.logout();
        // Bu chiqish yo'lida ham kesh tozalanadi.
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
      state = AuthError(
        'auth.errors.saveSessionFailed'.tr(namedArgs: {'error': '$e'}),
      );
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
      return friendlyError(e, fallback: 'auth.errors.signInFailed'.tr());
    } catch (_) {
      return 'auth.errors.unexpected'.tr();
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
      return friendlyError(e, fallback: 'auth.errors.signUpFailed'.tr());
    } catch (_) {
      return 'auth.errors.unexpected'.tr();
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
      return friendlyError(e, fallback: 'auth.errors.googleFailed'.tr());
    } catch (e) {
      return 'auth.errors.googleFailedDetail'.tr(namedArgs: {'error': '$e'});
    }
  }

  /// Web render-tugma oqimidan kelgan TAYYOR Google idToken bilan kirish.
  Future<String?> signInWithGoogleIdToken(String idToken) async {
    try {
      final session = await _repo.loginWithGoogle(idToken: idToken);
      await _repo.saveSession(session);
      state = AuthAuthenticated(session.user);
      return null;
    } on DioException catch (e) {
      return friendlyError(e, fallback: 'auth.errors.googleFailed'.tr());
    } catch (e) {
      return 'auth.errors.googleFailedDetail'.tr(namedArgs: {'error': '$e'});
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
      return friendlyError(e, fallback: 'auth.errors.appleFailed'.tr());
    } catch (e) {
      return 'auth.errors.appleFailedDetail'.tr(namedArgs: {'error': '$e'});
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    // SWR disk-keshi tozalanadi — keyingi akkaunt oldingisining
    // bolalari/ma'lumotini ko'rmasligi kerak.
    await SwrCache.clearAll();
    state = const AuthAnonymous();
  }
}
