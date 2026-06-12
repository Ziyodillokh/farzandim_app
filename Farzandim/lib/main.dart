// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — Asosiy kirish nuqtasi (entry point)
// ─────────────────────────────────────────────────────────────────────
//
// Flutter dasturi `main()` funksiyasidan boshlanadi. Bu funksiya:
//   1) Flutter binding'larni ishga tushiradi (WidgetsFlutterBinding).
//   2) Firebase'ni inicializatsiya qiladi.
//   3) App Check faollashtiradi (Sprint 2.3 — Play Integrity/DeviceCheck).
//      Boshqa Firebase API'lardan oldin chaqirish kerak — Firestore/Auth
//      so'rovlari App Check tokenini olib yuboradi.
//   4) Crashlytics + Analytics hook'larini o'rnatadi (Sprint 1.5).
//   5) `runZonedGuarded` ichida `runApp(...)` chaqiradi — zone'dagi
//      uncaught xato'lar Crashlytics'ga yuboriladi.
//
// Debug build'da Crashlytics o'chirilgan (kDebugMode) — har kichik
// debugging xato Firebase Console'ga oqib ketmaydi.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/app.dart';
import 'package:farzandim/core/constants/api_keys.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart'
    show kPendingNotificationsPrefsKey;
import 'package:farzandim/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FCM xabari ILOVA FONDA/YOPIQ bo'lganda keladigan handler (alohida isolate).
///
/// FCM o'zi tray'da notification ko'rsatadi, lekin ilova ichidagi
/// "Bildirishnoma" ro'yxatiga tushmasdi (ro'yxat faqat foreground
/// xabarlarini olardi). Bu handler xabarni SharedPreferences "pending"
/// navbatiga yozadi — ilova ochilganda/resume bo'lganda
/// `NotificationsNotifier.syncPending()` uni ro'yxatga qo'shadi.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // allaqachon init bo'lgan bo'lishi mumkin
  }
  try {
    final notif = AppNotification.fromRemoteMessage(message);
    final prefs = await SharedPreferences.getInstance();
    // MUHIM: har xabar O'Z noyob kalitiga yoziladi (atomik bitta write) —
    // umumiy massiv kalitida read-modify-write QILMAYMIZ. Aks holda main
    // isolate'ning syncPending'i (reload→read→remove) bilan poyga bo'lib,
    // shu orada bg isolate qo'shgan xabar (hatto SOS) jimgina yo'qolishi
    // mumkin edi. Kalit microsecond bilan noyob; mantiqiy dedup syncPending'da
    // notif.id bo'yicha bo'ladi.
    final key = '$kPendingNotificationsPrefsKey:'
        '${DateTime.now().microsecondsSinceEpoch}_${notif.id}';
    await prefs.setString(key, jsonEncode(notif.toJson()));
  } catch (e) {
    debugPrint('FCM bg handler xato: $e');
  }
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ⚡ Yuqori refresh rate (120Hz) — Android'da eng yuqori display rejimini
      // so'raydi (Samsung va b. ilovani 60Hz'da cheklaydi). Web/iOS'da no-op
      // (iOS allaqachon avtomatik). Xato bo'lsa app baribir ishlaydi.
      // MUHIM (ST-02): mustaqil init'lar PARALLEL — avval 4 ta ketma-ket
      // await edi (displayMode → ApiKeys → EasyLocalization → Firebase),
      // cold start shuncha sekkinlashardi. Har biri o'z try/catch'ida —
      // bittasi yiqilsa qolganlari davom etadi.
      await Future.wait<void>([
        // ⚡ 120Hz — best-effort (qurilma qo'llamasa 60Hz qoladi).
        if (!kIsWeb)
          FlutterDisplayMode.setHighRefreshRate().catchError((Object _) {}),
        // API kalitlar (assets/env.json) — dart-define'siz ham ishlaydi.
        ApiKeys.init(),
        // easy_localization (SharedPreferences'dan til).
        EasyLocalization.ensureInitialized(),
        // Firebase core. DEV: config yo'q bo'lsa ham app ishga tushadi.
        Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).then<void>((_) {
          // Fonda kelgan push'larni "Bildirishnoma" ro'yxatiga saqlash uchun
          // background handler (web'da service worker — qo'llanmaydi).
          if (!kIsWeb) {
            FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler,
            );
          }
        }).catchError((Object e) {
          debugPrint('[DEV] Firebase init skipped: $e');
        }),
      ]);

      // App Check / Crashlytics / Analytics — faqat mobil (Android/iOS),
      // va faqat Firebase core muvaffaqiyatli bo'lganda. Web'da:
      //   • Analytics [400] "API key not valid" spam beradi,
      //   • Crashlytics web'ni qo'llamaydi, AppCheck reCAPTCHA talab qiladi.
      // Error-handler'lar SINXRON o'rnatiladi (erta xatolar tutilsin);
      // qolgan aktivatsiyalar birinchi frame'ni kechiktirmasligi uchun
      // AWAIT QILINMAYDI (plugin'lar chaqiriqlarni o'zi navbatga oladi).
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          // Crashlytics fail bo'lsa unhandled bo'lib qolmasin —
          // .catchError bilan yutib yuboramiz.
          FirebaseCrashlytics.instance
              .recordError(error, stack, fatal: true)
              .catchError((Object _) {
                debugPrint(
                  '[DEV] Crashlytics failed; uncaught: $error\n$stack',
                );
              });
          return true;
        };
        unawaited(
          Future.wait<void>([
            FirebaseAppCheck.instance.activate(
              androidProvider: kDebugMode
                  ? AndroidProvider.debug
                  : AndroidProvider.playIntegrity,
              appleProvider: kDebugMode
                  ? AppleProvider.debug
                  : AppleProvider.deviceCheck,
            ),
            FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
              !kDebugMode,
            ),
            FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
              !kDebugMode,
            ),
          ]).catchError((Object e) {
            debugPrint('[DEV] Firebase services init xato: $e');
            return <void>[];
          }),
        );
      }

      if (!kDebugMode) {
        ErrorWidget.builder = (_) => const _ErrorFallback();
      }

      runApp(
        EasyLocalization(
          // Qo'llab-quvvatlanadigan tillar — JSON fayllar
          // `assets/translations/{lang}.json` nomida bo'lishi shart.
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('uz'),
          startLocale: const Locale('uz'),
          child: const ProviderScope(child: FarzandimApp()),
        ),
      );
    },
    (error, stack) {
      // DEV: Firebase init bo'lmagan paytda Crashlytics chaqirilsa
      // `pluginConstants` assertion async error sifatida portlaydi.
      // Firebase.apps.isEmpty bilan birinchi tekshirib olamiz.
      if (Firebase.apps.isEmpty) {
        debugPrint('[DEV] Uncaught (no Firebase): $error\n$stack');
        return;
      }
      try {
        FirebaseCrashlytics.instance
            .recordError(error, stack, fatal: true)
            .catchError((Object _) {
              debugPrint('[DEV] Crashlytics failed; uncaught: $error\n$stack');
            });
      } catch (_) {
        debugPrint('[DEV] Uncaught: $error\n$stack');
      }
    },
  );
}

/// Release build'da widget render xatosida ko'rsatiladigan oddiy fallback.
/// `ErrorWidget.builder` chaqiradi — Material/Directionality ancestor'siz
/// ishlashi shart, shuning uchun o'zi Directionality bilan o'raladi.
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0A0A12),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'errors.fatalFallback'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB0B0B8), fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
