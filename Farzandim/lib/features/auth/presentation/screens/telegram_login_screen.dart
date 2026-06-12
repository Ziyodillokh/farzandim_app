// ─────────────────────────────────────────────────────────────────────
// TelegramLoginScreen — WebView Telegram Login Widget (Sprint 4.4)
// ─────────────────────────────────────────────────────────────────────
//
// Flow:
//   1. WebView ochiladi → https://farzandimedu.uz/login.html
//   2. Foydalanuvchi Telegram Login Widget orqali kirib chiqadi
//      (Telegram'da "Log In" tugmasi)
//   3. Backend cookie/session yaratadi, /api/auth/telegram chaqirib
//      JWT tokens oladi
//   4. login.html quyidagini bajaradi:
//        if (window.FlutterAuth) {
//          window.FlutterAuth.postMessage(JSON.stringify({
//            accessToken: "...", refreshToken: "...",
//            user: { id, role, ... }
//          }));
//        }
//   5. Flutter JavascriptChannel 'FlutterAuth' qabul qiladi → JSON parse →
//      BackendAuthNotifier.handleCallback() → state = AuthAuthenticated
//   6. AuthGuard / router redirect → /dashboard
//
// Eslatma: login.html bridge hozircha yo'q (Backend Claude yangilaydi).
// Bu fayl bridge tayyor bo'lganda darhol ishlashga tayyor.

import 'dart:convert';

import 'package:farzandim/core/config/env_config.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TelegramLoginScreen extends ConsumerStatefulWidget {
  const TelegramLoginScreen({super.key});

  @override
  ConsumerState<TelegramLoginScreen> createState() =>
      _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends ConsumerState<TelegramLoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  static const _loginPath = '/login.html';
  static const _flutterAuthChannel = 'FlutterAuth';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A12)) // app background
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _error = error.description;
              _loading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        _flutterAuthChannel,
        onMessageReceived: _onAuthMessage,
      )
      ..loadRequest(Uri.parse('${EnvConfig.apiBaseUrl}$_loginPath'));
  }

  Future<void> _onAuthMessage(JavaScriptMessage message) async {
    try {
      final raw = jsonDecode(message.message) as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint('TelegramLogin: FlutterAuth payload qabul qilindi');
      }

      // Backend kontrakt: { ok: bool, accessToken?, refreshToken?,
      //                     user?, error? }
      if (raw['ok'] != true) {
        if (!mounted) return;
        setState(() {
          _error = (raw['error'] as String?) ?? "Login xato (noma'lum)";
        });
        return;
      }

      // Parsing screen'da (notifier JSON shape'ni bilmaydi).
      final tokens = AuthTokens(
        accessToken: raw['accessToken'] as String,
        refreshToken: raw['refreshToken'] as String,
      );
      final user = AuthUser.fromJson(raw['user'] as Map<String, dynamic>);

      await ref
          .read(backendAuthProvider.notifier)
          .onLoggedIn(tokens, user);

      if (!mounted) return;
      // Router refreshListenable backendAuthProvider'ga listen qiladi —
      // state Authenticated bo'lsa avtomatik /dashboard'ga redirect.
      // Bu yerda faqat AuthError'ni UI'da ko'rsatish kerak.
      final state = ref.read(backendAuthProvider);
      if (state is AuthError) {
        setState(() => _error = state.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Login javobini o'qib bo'lmadi: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram bilan kirish'),
        backgroundColor: AppColors.surface,
      ),
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
