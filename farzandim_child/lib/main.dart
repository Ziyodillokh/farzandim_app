// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — Asosiy kirish nuqtasi
// ─────────────────────────────────────────────────────────────────────
//
// 1. WidgetsFlutterBinding.ensureInitialized — Firebase init'dan oldin.
// 2. Firebase.initializeApp — Firestore, Auth, FCM uchun majburiy.
// 3. ProviderScope — Riverpod ishlashi uchun ildiz widget.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';
import 'package:farzandim_child/core/realtime/socket_providers.dart';
import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/core/theme/app_theme.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/unlock_request_provider.dart';
import 'package:farzandim_child/core/theme/theme_mode_provider.dart';
import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim_child/features/app_update/presentation/dialogs/force_update_dialog.dart';
import 'package:farzandim_child/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:farzandim_child/features/background/data/services/background_service.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim_child/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global xato tutqichlari (crash himoyasi) ──────────────────────
  // Ba'zi qurilmalarda (ayniqsa Xiaomi/MIUI) ushlanmagan Flutter yoki
  // async xato platformaga o'tib butun ilovani yopib qo'yardi
  // ("ilovadan chiqib ketyapti"). Quyidagilar bunday xatolarni tutib,
  // log qiladi va `true` qaytarib platformaga o'tkazmaydi — ilova
  // ekranda qoladi (oq/qora crash o'rniga).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[GLOBAL FlutterError] ${details.exceptionAsString()}');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('[GLOBAL PlatformDispatcher] $error\n$stack');
    return true; // xato "handled" — ilova crash bo'lmaydi
  };

  // Google Fonts runtime fetching — web'da CORS/network bilan xato bersa
  // butun frame fail bo'ladi. Asset/bundled font yo'q bo'lsa system default
  // (Roboto) ishlatamiz. Mobil'da ham xavfsiz: offline holatda crash yo'q.
  GoogleFonts.config.allowRuntimeFetching = false;

  // ESLATMA: just_audio_background (background media servis) OLIB TASHLANDI —
  // release APK'da audiokitob JIM qolib duration 0 bo'lardi. Endi audiokitob
  // oddiy just_audio bilan ishlaydi (ovozli xabarlar kabi, ishonchli). Telefon
  // qulflanganda davom etish keyin alohida, sinab ko'rilgan holda qo'shiladi.

  // easy_localization init — JSON tarjima fayllarini yuklash uchun.
  await EasyLocalization.ensureInitialized();

  // DEV: Firebase config'siz ham app ishga tushsin (stub bilan kompilyatsiya
  // o'tadi, lekin runtime'da real loyiha kalit'lari bo'lmasa initializeApp
  // xato beradi). Auth/Firestore/FCM bunday holatda no-op.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[DEV] Firebase init skipped: $e');
  }

  // Data-only FCM background handler — 'location_wake' (ota-ona xaritani
  // ochganda app fonda bo'lsa ham yangi fix yuboriladi). Web'da yo'q.
  if (!kIsWeb) {
    try {
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    } catch (e) {
      debugPrint('[DEV] FCM background handler skipped: $e');
    }
  }

  // Locale ma'lumotlarini yuklash — `DateFormat('d MMMM', 'uz')` kabi
  // non-default locale ishlatilganda kerak (LocaleDataException oldini oladi).
  await initializeDateFormatting('uz_UZ', null);
  await initializeDateFormatting('ru_RU', null);

  // Foreground Service notification kanali va options.
  // Web'da no-op — flutter_foreground_task faqat Android/iOS.
  if (!kIsWeb) {
    BackgroundService.init();
  }

  // Offline buffer — internet qaytganda eski qoldiqlarni flush qiladi.
  OfflineBuffer().start();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('uz'),
        Locale('ru'),
        Locale('en'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      startLocale: const Locale('uz'),
      child: const ProviderScope(
        child: ChildApp(),
      ),
    ),
  );
}

class ChildApp extends ConsumerWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Sprint 4.4.8: FCM token Backend'ga register — Backend voice/video
    // push yuborganda Child App qabul qilish uchun.
    ref.watch(fcmInitializerProvider);

    // Sprint 4.4.11: Socket.io lifecycle — pairing state'ga listen
    // qilib avtomatik connect/disconnect (paired → connect).
    ref.watch(socketLifecycleProvider);

    // Bloklash overlay'idagi "Ruxsat so'rash" — native ilovani ochganda
    // kutilayotgan so'rovni backend'ga yuboradi (+ unlock bridge'ni tirik
    // qiladi, app ochiq paytdagi onUnlockRequested push'lari uchun).
    ref.watch(unlockPendingCheckProvider);

    // Sprint 4.4.28: app startup'da Backend'dan version tekshirish.
    // Force update kerak bo'lsa modal dialog ochish.
    // Birinchi qiymat — ref.watch (initial), keyingilari — ref.listen.
    final initialStatus = ref.watch(appUpdateProvider).valueOrNull;
    if (initialStatus != null &&
        initialStatus.state == UpdateState.forceUpdateRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext != null) {
          ForceUpdateDialog.show(navContext, initialStatus);
        }
      });
    }
    ref.listen<AsyncValue<AppUpdateStatus>>(
      appUpdateProvider,
      (previous, next) {
        final status = next.valueOrNull;
        if (status == null) return;
        if (status.state != UpdateState.forceUpdateRequired) return;
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ForceUpdateDialog.show(navContext, status);
        });
      },
    );

    // Sprint UI.4: theme mode Settings'dan keladi (light/dark/system).
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Parvoz',
      debugShowCheckedModeBanner: false,
      // Sprint UI.1: Light theme asosiy (Duolingo-style), dark fallback.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      // easy_localization delegate va supportedLocales —
      // `EasyLocalization` widget'idan keladi (yuqorida wrap qilingan).
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
