// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — Asosiy kirish nuqtasi
// ─────────────────────────────────────────────────────────────────────
//
// 1. WidgetsFlutterBinding.ensureInitialized — Firebase init'dan oldin.
// 2. Firebase.initializeApp — Firestore, Auth, FCM uchun majburiy.
// 3. ProviderScope — Riverpod ishlashi uchun ildiz widget.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/app/notif_strings_sync.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/growth/men/lock/lock_gate.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/core/realtime/socket_providers.dart';
import 'package:farzandim_child/core/routing/app_router.dart';
import 'package:farzandim_child/core/theme/app_theme.dart';
import 'package:farzandim_child/core/utils/release_logging.dart';
import 'package:farzandim_child/features/account/presentation/providers/language_sync_provider.dart';
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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farzandim_child/core/theme/app_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release build'da debugPrint jurnalga yozmaydi (koordinata, token va
  // so'rov tanalari qurilma log'iga tushmasin).
  silenceDebugPrintInRelease();

  // iPhone: interfeys faqat portret. Info.plist landshaftni ham saqlaydi —
  // video pleyerlar to'liq ekranda landshaftga o'tadi va chiqishda yana
  // portretga qaytaradi (App Store audit F48).
  if (PlatformCapabilities.isIOS) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

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

  // ESLATMA: audio_service 1.0.20 da olib tashlandi — u har dvigatel
  // (FGS, FCM) ulanganda ilovaning yashirin ikkinchi nusxasini (main())
  // ishga tushirib, fonda takroriy so'rovlar yuborardi. Audiokitoblar
  // (kShowAudioVideo=false bilan yashirin) faqat ilova ochiqligida
  // just_audio bilan ijro etiladi; global init shart emas.

  // ── PERF: init'lar PARALLEL (ketma-ket await o'rniga) ──────────────
  // Avval EasyLocalization → Firebase → date×2 KETMA-KET kutilardi (sekin
  // cold start). Endi hammasi parallel: Firebase (eng uzun, ~1-3s native)
  // bilan bir vaqtda localization + locale data yuklanadi. EasyLocalization
  // runApp'dagi widget'dan oldin tayyor bo'lishi shart — shuning uchun
  // Future.wait ichida (lekin Firebase bilan parallel). Akkauntlar ro'yxati
  // va ilova qulfi ham (xavfsiz xotira o'qishlari) shu bilan parallel —
  // ikkalasi xatoni o'zi ushlaydi.
  await Future.wait<void>([
    EasyLocalization.ensureInitialized(),
    _initFirebase(),
    // Locale data — DateFormat('d MMMM','uz') uchun (LocaleDataException oldini).
    initializeDateFormatting('uz_UZ', null),
    initializeDateFormatting('ru_RU', null),
    preloadAppFonts(),
    // v5: qurilmadagi akkauntlar (A10) — ildiz faol akkaunt bilan quriladi.
    AccountRegistry.instance.load(),
    // Ilova qulfi: kod bo'lsa — birinchi kadrdanoq qulf ekrani.
    AppLock.instance.load(),
  ]);

  // ── Crashlytics (faqat Firebase muvaffaqiyatli bo'lganda) ──────────
  // Yuqoridagi FlutterError/PlatformDispatcher handler'lar FAQAT
  // Flutter/Dart tarafidagi xatolarni tutadi. Android foreground
  // servislarida (RestrictionService, watchdog, UsageStatsPlugin va h.k.)
  // Kotlin darajasidagi crash bu handler'lardan O'TIB KETADI — Crashlytics
  // SDK esa native crash'larni ham ALOHIDA, avtomatik yozadi. "Ilova
  // ishdan chiqdi" holatlarini keyingi safar aniq stack trace bilan
  // tashxislash uchun MUHIM.
  //
  // Bu yerda tutilgan xatolar ilovani YOPMAYDI (handler `true` qaytaradi,
  // widget xatosi faqat o'sha widget'ni almashtiradi) — shuning uchun
  // fatal EMAS (`fatal: false`): aks holda crash-free statistikasi soxta
  // "crash"lar bilan to'lib, haqiqiy native crash'lar ko'rinmay qolardi.
  if (!kIsWeb && Firebase.apps.isNotEmpty) {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousOnError?.call(details);
      FirebaseCrashlytics.instance
          .recordFlutterError(details)
          .catchError((Object _) {});
    };
    final previousPlatformOnError =
        WidgetsBinding.instance.platformDispatcher.onError;
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      previousPlatformOnError?.call(error, stack);
      FirebaseCrashlytics.instance
          .recordError(error, stack, fatal: false, reason: 'ui-async')
          .catchError((Object _) {});
      return true;
    };
    unawaited(
      FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode)
          .catchError((Object e) {
            debugPrint('[DEV] Crashlytics enable xato: $e');
          }),
    );
  }

  // Foreground Service notification kanali. Web'da no-op. Tarjimalar bu
  // yerda HALI yuklanmagan — matnlar `NotifStringsSync` (MaterialApp
  // builder) orqali yuklangach yoziladi.
  if (!kIsWeb) {
    BackgroundService.init();
  }

  // ESLATMA: offline buffer'ni endi fon ishlarining yagona egasi (FGS
  // isolate'i yoki u ishlamasa UI isolate'dagi BackgroundJobs) flush qiladi —
  // bu yerda ikkinchi flusher ochilmaydi (dublikat/yo'qolgan nuqtalar).

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      startLocale: const Locale('uz'),
      child: AccountScope(
        registry: AccountRegistry.instance,
        child: const ChildApp(),
      ),
    ),
  );
}

/// Web uchun Firebase config. `firebase_options.dart` `.gitignore`da (deploy'ga
/// bormaydi) va web'da `currentPlatform` SINXRON throw qiladi. Shuning uchun
/// web konfiguratsiyani SHU YERDA (git kuzatadigan faylda) beramiz — deploy'da
/// ham ishlashi uchun. To'liq web push/auth uchun keyin `flutterfire configure`
/// bilan rasmiy web appId olinadi.
const _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCVQqj1-NIQwp9G566CS65ruw53Nzx6pDE',
  appId: '1:163835260058:web:bc9bac1f0fc5e301d30323',
  messagingSenderId: '163835260058',
  projectId: 'farzandim-mvp',
  authDomain: 'farzandim-mvp.firebaseapp.com',
  databaseURL:
      'https://farzandim-mvp-default-rtdb.asia-southeast1.firebasedatabase.app',
  storageBucket: 'farzandim-mvp.firebasestorage.app',
);

/// Firebase init — barcha platformalarda. Butun blok try/catch bilan: init
/// muvaffaqiyatsiz bo'lsa ham (masalan tarmoqsiz) ilova baribir ishga tushadi.
/// MUHIM: web'da `DefaultFirebaseOptions.currentPlatform` SINXRON throw qilardi
/// va u `initializeApp` argumenti bo'lgani uchun `.catchError` uni tutmasdi →
/// `main()` yiqilib, web app umuman yuklanmasdi. Endi web'da `_webFirebaseOptions`
/// ishlatiladi (currentPlatform umuman chaqirilmaydi).
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: kIsWeb
          ? _webFirebaseOptions
          : DefaultFirebaseOptions.currentPlatform,
    );
    // Data-only FCM background handler ('location_wake', 'restrictions_sync')
    // — FAQAT iOS. Android'da fon data push'larini native
    // FarzandimMessagingService FGS isolate'iga uzatadi: uchinchi (FCM)
    // Flutter engine ochilmaydi. Web'da service worker + VAPID kerak.
    if (PlatformCapabilities.isIOS) {
      try {
        FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
      } catch (e) {
        debugPrint('[DEV] FCM background handler skipped: $e');
      }
    }
  } catch (e) {
    debugPrint('[DEV] Firebase init skipped: $e');
  }
}

class ChildApp extends ConsumerStatefulWidget {
  const ChildApp({super.key});

  @override
  ConsumerState<ChildApp> createState() => _ChildAppState();
}

class _ChildAppState extends ConsumerState<ChildApp> {
  /// Majburiy yangilash oynasi shu navigatorda ochilganmi — har rebuild
  /// (FCM init, mavzu/til almashishi) yangi oyna qo'shib, yopib bo'lmaydigan
  /// oynalar ustma-ust yig'ilmasin.
  bool _isForceUpdateShown = false;

  /// Navigator hali qurilmagan bo'lsa shuncha kadr kutiladi.
  static const _maxForceUpdateFrames = 10;

  @override
  void initState() {
    super.initState();
    // Sprint 4.4.28: app startup'da Backend'dan version tekshirish. Bitta
    // tinglovchi (joriy qiymat ham) — force update kerak bo'lsa modal BIR
    // MARTA ochiladi.
    ref.listenManual<AsyncValue<AppUpdateStatus>>(
      appUpdateProvider,
      (_, next) => _maybeShowForceUpdate(next.valueOrNull),
      fireImmediately: true,
    );
  }

  void _maybeShowForceUpdate(AppUpdateStatus? status) {
    if (status == null || status.state != UpdateState.forceUpdateRequired) {
      return;
    }
    if (_isForceUpdateShown) return;
    _isForceUpdateShown = true;
    _showForceUpdateWhenReady(status, _maxForceUpdateFrames);
  }

  void _showForceUpdateWhenReady(AppUpdateStatus status, int framesLeft) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navContext = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (navContext != null) {
        unawaited(ForceUpdateDialog.show(navContext, status));
        return;
      }
      if (framesLeft <= 0) {
        // Navigator yo'q — keyingi holat o'zgarishida qayta urinamiz.
        _isForceUpdateShown = false;
        return;
      }
      _showForceUpdateWhenReady(status, framesLeft - 1);
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
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

    // Ilova tili bola hisobiga yoziladi (maktab so'rovnomasi va testlari shu
    // tilda keladi) — ulangandan keyin va til almashganda.
    ref.watch(languageSyncProvider);

    // Sprint UI.4: theme mode Settings'dan keladi (light/dark/system).
    final themeMode = ref.watch(themeModeProvider);

    // ── Til reaktivligi: locale → router refresh ──────────────────────
    // context.setLocale() faqat easy_localization holatini yangilaydi;
    // go_router sahifalarni cache qiladi (Navigator GlobalKey), shuning uchun
    // til almashganda cache'langan ekran (Profil badge'lari va h.k.) eski
    // tilda qolardi. Joriy locale'ni provider'ga sinxronlab, router refresh
    // orqali joriy sahifani QAYTA quramiz.
    final localeCode = context.locale.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localeNotifier = ref.read(localeRefreshProvider.notifier);
      if (localeNotifier.state != localeCode) {
        localeNotifier.state = localeCode;
      }
      // Server bilan til sinxronizatsiyasi (`languageSyncProvider`).
      final languageNotifier = ref.read(appLanguageProvider.notifier);
      if (languageNotifier.state != localeCode) {
        languageNotifier.state = localeCode;
      }
    });

    return MaterialApp.router(
      title: 'Parvoz Growth',
      debugShowCheckedModeBanner: false,
      // Sprint UI.1: Light theme asosiy (Duolingo-style), dark fallback.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      // Til o'zgarganda sahifa subtree'sini qayta quramiz (key o'zgaradi →
      // remount). go_router sahifalarni cache qilgani uchun oddiy rebuild
      // yetmaydi: locale key'da bo'lmasa til almashganda eski tilda qolib,
      // bir "refresh" talab qilardi. Route stack saqlanadi.
      //
      // `NotifStringsSync` — builder Localizations ICHIDA: tarjimalar
      // yuklangach (va har til almashganda) FGS bildirishnomasi va native
      // bloklash oynasi matnlari prefs'ga yoziladi (xom kalitlar emas).
      builder: (context, child) => NotifStringsSync(
        child: AppLockGate(
          lock: AppLock.instance,
          child: KeyedSubtree(
            key: ValueKey(context.locale.languageCode),
            child: G5TextScale(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
      // easy_localization delegate va supportedLocales —
      // `EasyLocalization` widget'idan keladi (yuqorida wrap qilingan).
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
