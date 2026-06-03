// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — UI PREVIEW HARNESS (faqat lokal test uchun)
// ─────────────────────────────────────────────────────────────────────
//
// Brauzerda (Chrome) UI'ni tez ko'rish va sinash uchun. ASOSIY ilova emas.
// Real ilovaning `routerProvider`'ini ishlatadi — barcha ekranlar + auth
// guard bor (anonim foydalanuvchi welcome'ga qaytariladi, shuning uchun
// login qilmasdan dashboard/bola-qo'shish ekranlariga kira olmaydi).
//
// Token brauzer localStorage'da saqlanadi (SharedPreferences) — sahifa
// yangilanganda ham kirgan holatda qolasiz.
//
// Eslatma: ba'zi ekranlar native plugin talab qiladi (Google Maps, kamera,
// WebView) — web'da cheklangan. To'liq funksional test uchun mobil APK.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/auth/token_storage.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        // Web preview'da flutter_secure_storage WebCrypto'ni chetlab,
        // tokenlarni localStorage (SharedPreferences)'da saqlaymiz —
        // OperationError yo'q VA sahifa yangilanganda token saqlanadi.
        tokenStorageProvider.overrideWithValue(_WebTokenStorage()),
        // API URL'ni joriy brauzer host'idan olamiz: sahifa qaysi IP'da
        // ochilgan bo'lsa, backend ham o'sha IP:3000 da. IP o'zgarsa ham
        // qayta build shart emas.
        apiBaseUrlProvider.overrideWithValue(
          'http://${Uri.base.host}:3000/api',
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('uz'),
        startLocale: const Locale('uz'),
        child: const _PreviewApp(),
      ),
    ),
  );
}

class _PreviewApp extends ConsumerWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kirish/xato bo'lsa snackbar ko'rsatamiz (navigatsiyani router'ning
    // auth-guard redirect'i o'zi qiladi: login → dashboard, logout → welcome).
    ref.listen<BackendAuthState>(backendAuthProvider, (prev, next) {
      if (next is AuthAuthenticated) {
        _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '✓ Kirildi: ${next.user.displayName ?? next.user.id}',
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
      } else if (next is AuthError) {
        _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Farzandim — UI Preview',
      scaffoldMessengerKey: _messengerKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A12),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

/// Web preview uchun localStorage (SharedPreferences) token storage —
/// flutter_secure_storage WebCrypto'ni chetlab o'tadi (OperationError yo'q)
/// va tokenlarni sahifa yangilanganda saqlaydi. Mobil ilovada native
/// Keychain/Keystore ishlatiladi — bu faqat web preview uchun.
class _WebTokenStorage extends TokenStorage {
  static const _kAccess = 'preview_jwt_access';
  static const _kRefresh = 'preview_jwt_refresh';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccess, accessToken);
    await p.setString(_kRefresh, refreshToken);
  }

  @override
  Future<String?> readAccessToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAccess);
  }

  @override
  Future<String?> readRefreshToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRefresh);
  }

  @override
  Future<void> updateAccessToken(String newAccessToken) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccess, newAccessToken);
  }

  @override
  Future<void> updateRefreshToken(String newRefreshToken) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRefresh, newRefreshToken);
  }

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
  }

  @override
  Future<bool> hasValidSession() async {
    final p = await SharedPreferences.getInstance();
    final r = p.getString(_kRefresh);
    return r != null && r.isNotEmpty;
  }
}
