import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/realtime/socket_providers.dart';
import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_theme.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim/features/app_update/presentation/dialogs/force_update_dialog.dart';
import 'package:farzandim/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/features/pair_requests/presentation/providers/pair_request_providers.dart';
import 'package:farzandim/features/sos/presentation/providers/sos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Farzandim ilovasining ildiz widget'i.
///
/// `ConsumerWidget` — quyidagi provider'larga obuna:
/// - `routerProvider`: auth state o'zgarganda router redirect'ni
///   qayta hisoblaydi.
/// - `fcmInitializerProvider`: FCM tizimini lazy ishga tushiradi
///   (FutureProvider — bir marta init).
/// - `socketLifecycleProvider`: Backend auth state'ga reaksiya bilan
///   Socket.io connect/disconnect (Sprint 4.4.1 Day 2).
class FarzandimApp extends ConsumerWidget {
  /// `FarzandimApp` konstruktor.
  const FarzandimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FCM init triggeri — birinchi build'da ishga tushadi va keshlanadi.
    // Natijaga (AsyncValue<void>) e'tibor bermaymiz — xato bo'lsa
    // `fcm_service.dart` ichida `debugPrint` qiladi.
    ref.watch(fcmInitializerProvider);

    // Socket.io lifecycle — auth state'ga listen qilib avtomatik
    // connect/disconnect qiladi. Side-effect, value qaytarmaydi.
    ref.watch(socketLifecycleProvider);

    // Theme (light/dark) — toggle'ga qarab AppColors.brightness o'rnatiladi.
    // Root build descendant'lardan OLDIN ishlaydi → keyin barcha widget'lar
    // to'g'ri rangni o'qiydi.
    final themeMode = ref.watch(themeModeProvider);
    AppColors.brightness = themeMode.brightness;

    // FCM token re-registratsiya — login muvaffaqiyatli tugagach.
    // `fcmInitializerProvider` token'ni startup'da yuboradi, ammo o'sha
    // paytda JWT yo'q bo'lsa 401 olib registratsiya bo'lmaydi. Auth
    // state `AuthAuthenticated`'ga o'tganda token qayta yoziladi —
    // shu bilan admin panel push'lari Parent App'ga yetib boradi.
    ref.listen<BackendAuthState>(backendAuthProvider, (previous, next) {
      if (next is AuthAuthenticated && previous is! AuthAuthenticated) {
        ref.read(fcmServiceProvider).reRegisterToken();
      }
    });

    // Sprint 4.4.7: SOS WS event'i — eng yuqori prioritet, qizil banner.
    ref.listen<AsyncValue<Map<String, dynamic>>>(sosReceivedAlertProvider,
        (_, next) {
      final payload = next.valueOrNull;
      if (payload == null || payload.isEmpty) return;
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 SOS! Bola yordam so\'ramoqda',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    // Sprint 4.4.25: Pair request created WS event — Parent App banner.
    ref.listen<AsyncValue<Map<String, dynamic>>>(pairRequestCreatedProvider,
        (_, next) {
      final payload = next.valueOrNull;
      if (payload == null || payload.isEmpty) return;
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      final childName = (payload['child'] as Map?)?['name'] as String? ??
          payload['childName'] as String? ??
          'Bola';
      final childId = payload['childId'] as String?;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '📱 $childName yangi qurilmadan ulanmoqchi. Tasdiqlang.',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          backgroundColor: const Color(0xFFFBBF24),
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          action: childId != null
              ? SnackBarAction(
                  label: 'Ko\'rish',
                  textColor: Colors.black,
                  onPressed: () {
                    final router = ref.read(routerProvider);
                    router.push(AppRoutes.pairRequestsPath(childId));
                  },
                )
              : null,
        ),
      );
    });

    // Sprint 4.4.3: Geo zone alert WS event'i — har joydan ko'rinadigan
    // SnackBar (Foreground). Background'da Backend FCM push yuboradi.
    ref.listen<AsyncValue<Map<String, dynamic>>>(geoZoneAlertProvider,
        (_, next) {
      final payload = next.valueOrNull;
      if (payload == null || payload.isEmpty) return;
      final messengerKey = _scaffoldMessengerKey;
      final messenger = messengerKey.currentState;
      if (messenger == null) return;
      final zoneName = payload['zoneName'] as String? ?? 'Zona';
      final isEnter = payload['event'] == 'enter';
      final action = isEnter ? 'kirdi' : 'chiqdi';
      messenger.showSnackBar(
        SnackBar(
          content: Text('🚨 Bola "$zoneName" zonasiga $action'),
          backgroundColor: isEnter
              ? const Color(0xFF4ADE80)
              : const Color(0xFFFBBF24),
          duration: const Duration(seconds: 4),
        ),
      );
    });

    // Sprint 4.4.28: app startup'da Backend'dan version tekshirish.
    // Force update kerak bo'lsa modal dialog (eski versiya bilan ishlatish
    // ta'qiqlangan). Soft update — Dashboard top banner'da ko'rinadi.
    // Birinchi qiymat — ref.watch (initial), keyingilari — ref.listen.
    final initialUpdateStatus = ref.watch(appUpdateProvider).valueOrNull;
    if (initialUpdateStatus != null &&
        initialUpdateStatus.state == UpdateState.forceUpdateRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final router = ref.read(routerProvider);
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext != null) {
          ForceUpdateDialog.show(navContext, initialUpdateStatus);
        }
      });
    }
    ref.listen<AsyncValue<AppUpdateStatus>>(
      appUpdateProvider,
      (previous, next) {
        final status = next.valueOrNull;
        if (status == null) return;
        if (status.state != UpdateState.forceUpdateRequired) return;
        final router = ref.read(routerProvider);
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ForceUpdateDialog.show(navContext, status);
        });
      },
    );

    return MaterialApp.router(
      title: 'Farzandim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      // easy_localization delegate va supportedLocales — `EasyLocalization`
      // widget'idan keladi (main.dart'da o'ralgan). `context.locale` ham
      // shu yerdan o'qiladi.
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

/// Global ScaffoldMessenger key — geo zone alert SnackBar har joydan
/// ko'rinishi uchun (router shape'idan tashqarida ham). Sprint 4.4.3.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
