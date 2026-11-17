// ─────────────────────────────────────────────────────────────────────
// ChildBackgroundTaskHandler — Foreground Service ichida ishlovchi Dart
// ─────────────────────────────────────────────────────────────────────
//
// flutter_foreground_task ilovaning asosiy isolate'idan alohida
// isolate'da bu kodni ishga tushiradi. Shu sababli:
//   - Firebase'ni qayta init qilish kerak (har isolate'da alohida);
//   - xatolar Crashlytics'ga (fatal: false, reason 'bg-isolate') —
//     release'da debugPrint jim, aks holda fondagi nosozlik ko'rinmasdi;
//   - SharedPreferences'dan parentUid/childId tiklab olamiz (yo'q — servis
//     to'xtatiladi).
//
// Barcha fon ishlari BITTA BackgroundJobs'da. Trigger'lar:
//   onReceiveData  — native/UI xabarlari ('parvoz:tick', 'parvoz:screen_on',
//                    'parvoz:restrictions_sync', 'parvoz:location_wake',
//                    'parvoz:strings');
//   onRepeatEvent  — 5 daqiqalik zaxira (faqat qurilma uyg'oq paytda).
// onStart hech qachon tarmoqni kutmaydi. Bildirishnoma matni statik
// (har daqiqa yangilanmaydi).
//
// Eslatma: `backgroundEntry` top-level + @pragma('vm:entry-point') —
// Flutter Engine isolate'ni boshlash uchun shu shartlarni qo'yadi.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/utils/release_logging.dart';
import 'package:farzandim_child/features/background/data/services/background_jobs.dart';
import 'package:farzandim_child/features/background/data/services/background_task_config.dart';
import 'package:farzandim_child/features/background/data/services/background_telemetry.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/firebase_options.dart';

@pragma('vm:entry-point')
void backgroundEntry() {
  silenceDebugPrintInRelease();
  FlutterForegroundTask.setTaskHandler(ChildBackgroundTaskHandler());
}

class ChildBackgroundTaskHandler extends TaskHandler {
  static const _fcmTimeout = Duration(seconds: 60);

  BackgroundJobs? _jobs;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 1. Yangi isolate'da Firebase init majburiy (Crashlytics uchun ham).
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // App allaqachon initialised — qaytarib o'rinish kerak emas.
    }
    _installErrorReporting();

    try {
      // 2. Pairing ma'lumoti (yangi isolate — prefs yangidan o'qiladi).
      final prefs = await SharedPreferences.getInstance();
      final parentUid = prefs.getString('parentUid');
      final childId = prefs.getString('childId');
      final childName = prefs.getString('childName') ?? 'Bola';
      if (parentUid == null || childId == null) {
        // Pair'lashmagan — service'ni to'xtatamiz.
        await FlutterForegroundTask.stopService();
        return;
      }

      // 3. Plagin saqlagan eski sozlama (doimiy WakeLock, 60 s repeat) va
      // bildirishnoma matnini yangilaymiz — tizim servisni keyingi safar
      // (boot / yangilanish) shu bilan ko'taradi.
      unawaited(_refreshServiceOptions(prefs));

      // 4. Fon ishlari: cheklovlar birinchi, qolgani kutilmaydi.
      final jobs = BackgroundJobs(
        childId: childId,
        parentUid: parentUid,
        childName: childName,
        onStringsChanged: _refreshNotification,
      );
      _jobs = jobs;
      await jobs.start();

      // 5. FCM token'ni backend'ga QAYTA ro'yxatdan o'tkazamiz (birinchi
      // pair'da UI isolate init() JWT'dan oldin ishlab token yetmagan
      // bo'lishi mumkin — "Baland ovoz" ring jim no-op bo'lardi).
      unawaited(_refreshFcmRegistration());
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'fgs.onStart');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Zaxira tick — asosiy tick native alarm'dan (`parvoz:tick`) keladi.
    final jobs = _jobs;
    if (jobs != null) unawaited(jobs.onTick());
  }

  @override
  void onReceiveData(Object data) {
    final jobs = _jobs;
    if (jobs == null || data is! String) return;
    unawaited(jobs.onMessage(data));
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _jobs?.stop();
    _jobs = null;
  }

  @override
  void onNotificationPressed() {
    // Foydalanuvchi notificationga bossa — ilovani ochamiz.
    FlutterForegroundTask.launchApp();
  }

  /// Fon isolate'idagi kutilmagan xatolar Crashlytics'ga (crash EMAS).
  static void _installErrorReporting() {
    if (Firebase.apps.isEmpty) return;
    FlutterError.onError = (details) =>
        _record(details.exception, details.stack ?? StackTrace.current, '');
    PlatformDispatcher.instance.onError = (error, stack) {
      _record(error, stack, '');
      return true;
    };
    BackgroundTelemetry.reporter = _record;
  }

  static void _record(Object error, StackTrace stack, String where) {
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(
            error,
            stack,
            fatal: false,
            reason: where.isEmpty ? 'bg-isolate' : 'bg-isolate: $where',
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> _refreshServiceOptions(SharedPreferences prefs) async {
    try {
      final result = await FlutterForegroundTask.updateService(
        foregroundTaskOptions: BackgroundTaskConfig.taskOptions,
        notificationTitle:
            _cached(prefs, BackgroundTaskConfig.prefsTitleKey) ??
            BackgroundTaskConfig.fallbackTitle,
        notificationText:
            _cached(prefs, BackgroundTaskConfig.prefsTextKey) ??
            BackgroundTaskConfig.fallbackText,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('[BG] sozlamani yangilash xato: ${result.error}');
      }
    } catch (e, s) {
      BackgroundTelemetry.report(e, s, 'fgs.updateOptions');
    }
  }

  /// `parvoz:strings` — UI isolate yangi tarjimani yozdi (til o'zgardi).
  Future<void> _refreshNotification() async {
    final prefs = await SharedPreferences.getInstance();
    // UI isolate yozgan qiymatni ko'rish uchun reload SHART.
    await prefs.reload();
    final title = _cached(prefs, BackgroundTaskConfig.prefsTitleKey);
    final text = _cached(prefs, BackgroundTaskConfig.prefsTextKey);
    if (title == null && text == null) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title ?? BackgroundTaskConfig.fallbackTitle,
      notificationText: text ?? BackgroundTaskConfig.fallbackText,
    );
  }

  /// UI keshlagan tarjima (xom kalit bo'lsa — yo'q deb).
  static String? _cached(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value is! String || value.isEmpty || value.startsWith('background.')) {
      return null;
    }
    return value;
  }

  Future<void> _refreshFcmRegistration() async {
    try {
      await FcmService(
        backendRepo: BackendFcmRepository(
          dio: createBackendDio(TokenStorage()),
        ),
      ).refreshRegistration().timeout(_fcmTimeout);
    } catch (e) {
      debugPrint('[BG] FCM ro\'yxatdan o\'tkazish xato: $e');
    }
  }
}
