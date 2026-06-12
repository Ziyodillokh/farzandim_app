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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium silliq scroll — iOS uslubidagi bouncing fizika (ham web, ham
/// native). Sichqoncha/trackpad bilan ham drag (web'da test qulay).
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

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
    ref
      // FCM init triggeri — birinchi build'da ishga tushadi va keshlanadi.
      // Natijaga (AsyncValue<void>) e'tibor bermaymiz — xato bo'lsa
      // `fcm_service.dart` ichida `debugPrint` qiladi.
      ..watch(fcmInitializerProvider)
      // Socket.io lifecycle — auth state'ga listen qilib avtomatik
      // connect/disconnect qiladi. Side-effect, value qaytarmaydi.
      ..watch(socketLifecycleProvider);

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
    ref
      ..listen<BackendAuthState>(backendAuthProvider, (previous, next) {
        if (next is AuthAuthenticated && previous is! AuthAuthenticated) {
          ref.read(fcmServiceProvider).reRegisterToken();
        }
      })
      // Sprint 4.4.7: SOS WS event'i — eng yuqori prioritet, qizil banner.
      ..listen<AsyncValue<Map<String, dynamic>>>(sosReceivedAlertProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🚨 ${'sos.wsBanner'.tr()}',
                    style: const TextStyle(
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
            // Bosilsa — SOS alertlar ro'yxatiga o'tadi (xarita + tafsilot +
            // "hal qilindi"). Pair-request banner bilan bir xil pattern.
            action: SnackBarAction(
              label: 'sos.viewAction'.tr(),
              textColor: Colors.white,
              onPressed: () =>
                  ref.read(routerProvider).push(AppRoutes.sosAlerts),
            ),
          ),
        );
      })
      // Sprint 4.4.25: Pair request created WS event — Parent App banner.
      ..listen<AsyncValue<Map<String, dynamic>>>(pairRequestCreatedProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;
        final childName =
            (payload['child'] as Map?)?['name'] as String? ??
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
                    label: "Ko'rish",
                    textColor: Colors.black,
                    onPressed: () => ref
                        .read(routerProvider)
                        .push(AppRoutes.pairRequestsPath(childId)),
                  )
                : null,
          ),
        );
      })
      // Sprint 4.4.3: Geo zone alert WS event'i — har joydan ko'rinadigan
      // SnackBar (Foreground). Background'da Backend FCM push yuboradi.
      ..listen<AsyncValue<Map<String, dynamic>>>(geoZoneAlertProvider, (
        _,
        next,
      ) {
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
          ),
        );
      });

    // Sprint 4.4.28: app startup'da Backend'dan version tekshirish.
    // Force update kerak bo'lsa modal dialog (eski versiya bilan ishlatish
    // ta'qiqlangan). Soft update — Dashboard top banner'da ko'rinadi.
    // Birinchi qiymat — ref.watch (initial), keyingilari — ref.listen.
    final initialUpdateStatus = ref.watch(appUpdateProvider).valueOrNull;
    if (initialUpdateStatus != null &&
        initialUpdateStatus.state == UpdateState.forceUpdateRequired &&
        !_forceUpdateDialogShown) {
      _forceUpdateDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final router = ref.read(routerProvider);
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext != null) {
          ForceUpdateDialog.show(navContext, initialUpdateStatus);
        }
      });
    }
    ref.listen<AsyncValue<AppUpdateStatus>>(appUpdateProvider, (
      previous,
      next,
    ) {
      final status = next.valueOrNull;
      if (status == null) return;
      if (status.state != UpdateState.forceUpdateRequired) return;
      if (_forceUpdateDialogShown) return;
      _forceUpdateDialogShown = true;
      final router = ref.read(routerProvider);
      final navContext = router.routerDelegate.navigatorKey.currentContext;
      if (navContext == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ForceUpdateDialog.show(navContext, status);
      });
    });

    return MaterialApp.router(
      title: 'Farzandim',
      debugShowCheckedModeBanner: false,
      // ⚡ Premium silliq scroll — iOS uslubidagi bouncing fizika (web+native).
      scrollBehavior: const _AppScrollBehavior(),
      theme: AppTheme.build(),
      // Light/dark almashishda Theme.of() asoslangan widget'lar 200ms
      // crossfade qiladi, AppColors getter'lari esa darhol flip qiladi —
      // bu "yarim-animatsiya" nomuvofiqligi jank beradi. Zero qilib bir
      // kadrda BIRGA, aniq va tez almashtiramiz (professional).
      themeAnimationDuration: Duration.zero,
      // Global baza fon — BARCHA route'lar ortida theme rangi turadi.
      // Transparent scaffold'larda overscroll/pull-to-refresh paytida oq OS
      // oyna foni ko'rinmaydi (bitta joyda hal — har ekranni o'zgartirish
      // shart emas).
      builder: (context, child) => ColoredBox(
        color: AppColors.background,
        // ⚡ THEME REAKTIVLIK: light↔dark toggle'da sahifa subtree'sini QAYTA
        // quramiz (key o'zgaradi → remount). AppColors static getter'lari yangi
        // rangni o'qiydi — aks holda kartalar eski fonida qolardi (yangilash
        // shart edi). go_router route stack saqlanadi.
        child: KeyedSubtree(
          key: ValueKey(themeMode),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
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

/// Force-update dialogi BIR MARTA ochilsin — busiz har rebuild'da
/// (`ref.watch(appUpdateProvider)` build ichida) dialog ustma-ust qayta
/// ochilardi (ARCH-10).
bool _forceUpdateDialogShown = false;
