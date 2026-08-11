// Ilova kirish nuqtasi: Firebase/App Check/Crashlytics init va runApp.
// Debug build'da Crashlytics o'chirilgan — har mayda xato Console'ga oqmasin.

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
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ilova fonda yoki yopiq bo'lganda keladigan FCM xabarlari (alohida isolate).
///
/// FCM tray'da notification ko'rsatadi-yu, ilova ichidagi "Bildirishnoma"
/// ro'yxatiga tushmay qolardi. Shu uchun xabarni SharedPreferences "pending"
/// navbatiga yozamiz — ilova ochilganda `syncPending()` ro'yxatga qo'shadi.
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
    // Har xabar o'z noyob kalitiga yoziladi (bitta atomik write). Umumiy
    // massiv kalitida read-modify-write qilsak, main isolate'ning syncPending'i
    // bilan poyga chiqib, bg isolate qo'shgan xabar (hatto SOS) jim yo'qolishi
    // mumkin edi. Kalit microsecond bilan noyob; dedup syncPending'da
    // notif.id bo'yicha.
    final key =
        '$kPendingNotificationsPrefsKey:'
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

      // Android'ning ZAMONAVIY foto-tanlagichi (Android Photo Picker).
      //
      // ⚠️ Play talabi (2026-08-14): ilova READ_MEDIA_IMAGES/READ_MEDIA_VIDEO
      // so'ramasdan, tizim tanlagichidan foydalanishi shart. Bu bayroq
      // `image_picker`ni ACTION_PICK_IMAGES (Android 13+, eskiroq versiyalarda
      // Play services orqali backport) ga o'tkazadi — ruxsat umuman kerak
      // bo'lmaydi va foydalanuvchi butun galereyaga kirish huquqini bermaydi.
      // Tanlagich mavjud bo'lmasa plagin o'zi ACTION_GET_CONTENT'ga qaytadi
      // (u ham tizim tanlagichi, ruxsatsiz ishlaydi) — xavfsiz fallback.
      final picker = ImagePickerPlatform.instance;
      if (picker is ImagePickerAndroid) {
        picker.useAndroidPhotoPicker = true;
      }

      // Mustaqil init'lar parallel ketadi — avval 4 ta ketma-ket await edi
      // va cold start shunga cho'zilardi. Har biri o'z catch'ida: bittasi
      // yiqilsa qolganlari davom etadi.
      await Future.wait<void>([
        // 120Hz so'rov — best-effort (Samsung va b. 60Hz'da cheklaydi,
        // qurilma qo'llamasa 60Hz qoladi). Web/iOS'da no-op.
        if (!kIsWeb)
          FlutterDisplayMode.setHighRefreshRate().catchError((Object _) {}),
        // API kalitlar (assets/env.json) — dart-define'siz ham ishlaydi.
        ApiKeys.init(),
        // easy_localization (SharedPreferences'dan til).
        EasyLocalization.ensureInitialized(),
        // Firebase core. DEV: config yo'q bo'lsa ham app ishga tushadi.
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
            .then<void>((_) {
              // Fonda kelgan push'larni ro'yxatga saqlash uchun background
              // handler (web'da service worker — qo'llanmaydi).
              if (!kIsWeb) {
                FirebaseMessaging.onBackgroundMessage(
                  firebaseMessagingBackgroundHandler,
                );
              }
            })
            .catchError((Object e) {
              debugPrint('[DEV] Firebase init skipped: $e');
            }),
      ]);

      // App Check / Crashlytics / Analytics — faqat mobil va faqat Firebase
      // core muvaffaqiyatli bo'lganda (web'da Analytics 400 spam beradi,
      // Crashlytics web'ni qo'llamaydi). Error-handler'lar sinxron o'rnatiladi,
      // erta xatolar ham tutilsin; qolgan aktivatsiyalarni await qilmaymiz —
      // birinchi frame kechikmasin (plugin'lar chaqiriqlarni o'zi navbatlaydi).
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        FlutterError.onError = (details) {
          // Debug'da xatoni AVVAL konsolga chiqaramiz. Busiz Crashlytics
          // handler'i standart ishlovchini butunlay almashtiradi va framework
          // xatolari (overflow, assertion) hech qayerda ko'rinmaydi — faqat
          // ekrandagi qizil quti qoladi, stack trace yo'qoladi. Diagnostikani
          // imkonsiz qiladi (2026-08-11 da aynan shu sabab bola qo'shish
          // ekranidagi xatoni topish qiyin bo'ldi).
          if (kDebugMode) FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
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
    return const Directionality(
      textDirection: ui.TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF0A0A12),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              // Ataylab .tr() ishlatilmagan: ErrorWidget.builder
              // EasyLocalization yuklanishidan oldin ham ishlashi mumkin,
              // u holda .tr() tarjima o'rniga xom kalit nomini ko'rsatib
              // qo'yardi.
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
