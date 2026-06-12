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

/// iOS uslubidagi bouncing scroll fizika (web va native).
/// Sichqoncha/trackpad bilan ham drag ishlaydi — web'da test qulay.
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

/// Ildiz widget — router, FCM init va socket lifecycle provider'lariga
/// obuna bo'lib, WS event'lar uchun global banner'larni ko'rsatadi.
class FarzandimApp extends ConsumerWidget {
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

    // Toggle'ga qarab AppColors.brightness o'rnatiladi. Root build
    // descendant'lardan oldin ishlaydi, shuning uchun keyin barcha
    // widget'lar to'g'ri rangni o'qiydi.
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
      // SOS WS event'i — eng yuqori prioritet, qizil banner.
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
      // Pair request yaratildi WS event'i — sariq banner.
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
            'pairRequests.fallbackChildName'.tr();
        final childId = payload['childId'] as String?;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'childManagement.pairBanner.message'.tr(
                namedArgs: {'name': childName},
              ),
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
                    label: 'sos.viewAction'.tr(),
                    textColor: Colors.black,
                    onPressed: () => ref
                        .read(routerProvider)
                        .push(AppRoutes.pairRequestsPath(childId)),
                  )
                : null,
          ),
        );
      })
      // Geo zone alert WS event'i — foreground'da har joydan ko'rinadigan
      // SnackBar. Background'da backend FCM push yuboradi.
      ..listen<AsyncValue<Map<String, dynamic>>>(geoZoneAlertProvider, (
        _,
        next,
      ) {
        final payload = next.valueOrNull;
        if (payload == null || payload.isEmpty) return;
        final messengerKey = _scaffoldMessengerKey;
        final messenger = messengerKey.currentState;
        if (messenger == null) return;
        final zoneName =
            payload['zoneName'] as String? ??
            'dashboard.geoZoneAlert.zoneFallback'.tr();
        final isEnter = payload['event'] == 'enter';
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              (isEnter
                      ? 'dashboard.geoZoneAlert.enter'
                      : 'dashboard.geoZoneAlert.exit')
                  .tr(namedArgs: {'zone': zoneName}),
            ),
            backgroundColor: isEnter
                ? const Color(0xFF4ADE80)
                : const Color(0xFFFBBF24),
          ),
        );
      });

    // Startup'da backend'dan versiya tekshiruvi. Force update bo'lsa modal
    // dialog (eski versiya bilan ishlash taqiqlanadi), soft update Dashboard
    // banner'ida ko'rinadi. Birinchi qiymat ref.watch'dan, keyingilari
    // ref.listen orqali.
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
      scrollBehavior: const _AppScrollBehavior(),
      theme: AppTheme.build(),
      // Light/dark almashishda Theme.of() widget'lari 200ms crossfade
      // qiladi, AppColors getter'lari esa darhol flip qiladi — bu
      // nomuvofiqlik jank beradi. Zero qilib hammasini bir kadrda
      // almashtiramiz.
      themeAnimationDuration: Duration.zero,
      // Global baza fon — barcha route'lar ortida theme rangi turadi.
      // Transparent scaffold'larda overscroll paytida oq OS oyna foni
      // ko'rinib qolmasin; bitta joyda hal qilingani uchun har ekranni
      // alohida o'zgartirish shart emas.
      builder: (context, child) => ColoredBox(
        color: AppColors.background,
        // Light/dark toggle'da sahifa subtree'sini qayta quramiz (key
        // o'zgaradi, remount bo'ladi) — shunda AppColors static getter'lari
        // yangi rangni o'qiydi, aks holda kartalar eski fonida qolardi.
        // go_router route stack saqlanadi.
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

/// Global ScaffoldMessenger key — WS banner'lar har qanday ekranda
/// ko'rinishi uchun (router shape'idan tashqarida ham).
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Force-update dialogi bir marta ochilsin — busiz build ichidagi
/// `ref.watch(appUpdateProvider)` tufayli har rebuild'da dialog ustma-ust
/// qayta ochilardi.
bool _forceUpdateDialogShown = false;
