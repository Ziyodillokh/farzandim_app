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
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/app.dart';
import 'package:farzandim/core/constants/api_keys.dart';
import 'package:farzandim/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ⚡ Yuqori refresh rate (120Hz) — Android'da eng yuqori display rejimini
      // so'raydi (Samsung va b. ilovani 60Hz'da cheklaydi). Web/iOS'da no-op
      // (iOS allaqachon avtomatik). Xato bo'lsa app baribir ishlaydi.
      if (!kIsWeb) {
        try {
          await FlutterDisplayMode.setHighRefreshRate();
        } catch (_) {
          // best-effort — qurilma qo'llab-quvvatlamasa 60Hz qoladi
        }
      }

      // API kalitlarni runtime'da assets/env.json'dan yuklash —
      // --dart-define-from-file flag'siz ham ishlaydi.
      await ApiKeys.init();

      // easy_localization init.
      await EasyLocalization.ensureInitialized();

      // DEV: Firebase setup yo'q paytda ham app ishga tushsin.
      // Try/catch ichida — agar Firebase config to'g'ri bo'lmasa, app baribir
      // ishlaydi (Crashlytics/Analytics/AppCheck no-op).
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // App Check / Crashlytics / Analytics — faqat mobil (Android/iOS).
        // Web preview build'da ular kerak emas va konsolni xato bilan
        // to'ldiradi:
        //   • Analytics web API kalit bilan dynamic-config fetch qiladi →
        //     [400] "API key not valid" (har screen_view'da takrorlanadi).
        //   • Crashlytics web platformani umuman qo'llab-quvvatlamaydi.
        //   • App Check web uchun reCAPTCHA provider talab qiladi.
        // Shu sababli web'da Firebase faqat core init bo'ladi.
        if (!kIsWeb) {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider: kDebugMode
                ? AppleProvider.debug
                : AppleProvider.deviceCheck,
          );
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
            !kDebugMode,
          );
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
          await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
            !kDebugMode,
          );
        }
      } catch (e) {
        debugPrint('[DEV] Firebase init skipped: $e');
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
    return const Directionality(
      textDirection: ui.TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF0A0A12),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nimadir xato ketdi. Iltimos, ilovani qayta oching.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB0B0B8), fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
