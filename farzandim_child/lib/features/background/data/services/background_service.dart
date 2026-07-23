// ─────────────────────────────────────────────────────────────────────
// BackgroundService — Foreground Service'ni boshqaruvchi yuqori darajadagi API
// ─────────────────────────────────────────────────────────────────────
//
// PairingNotifier shu klassdan foydalanadi:
//   await backgroundService.start();   // pair'lashgach
//   await backgroundService.stop();    // unpair'lashganda
//
// init() main.dart'da bir marta chaqiriladi: notification kanali va
// ForegroundTaskOptions sozlanadi (autoRunOnBoot: true → telefon
// yoqilgach service o'zi qayta ishga tushadi).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/background/data/services/child_background_task_handler.dart';

class BackgroundService {
  /// Notification kanali va options'ni sozlash. main.dart'dan chaqiriladi.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'farzandim_child_bg',
        channelName: 'background.channelName'.tr(),
        channelDescription: 'background.channelDescription'.tr(),
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Har 60 sek onRepeatEvent chaqiriladi (notification matni yangilash)
        eventAction: ForegroundTaskEventAction.repeat(60 * 1000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    // BG isolate `.tr()` ishlata olmaydi → tarjimani hozir (main isolate)
    // prefs'ga yozamiz (pastdagi izohga qarang).
    unawaited(_cacheNotifStrings());
  }

  /// BG isolate `.tr()` ISHLATA OLMAYDI — easy_localization o'sha isolate'da
  /// yuklanmagan, shu sabab `onRepeatEvent`da xom kalit ("background.
  /// notificationTitle") ko'rinardi. Yechim: main isolate'da (bu yerda)
  /// tarjima qilib SharedPreferences'ga yozamiz; `onRepeatEvent` (bg isolate)
  /// `reload()` bilan o'qiydi. `init()` (har app start, saqlangan til bilan)
  /// va `start()`da yoziladi.
  static Future<void> _cacheNotifStrings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'bg.notifTitle',
        'background.notificationTitle'.tr(),
      );
      await prefs.setString(
        'bg.notifText',
        'background.notificationText'.tr(),
      );
      // {time} joy-egasi qoladi (namedArgs'siz .tr()) — bg isolate almashtiradi.
      await prefs.setString('bg.lastUpdateTpl', 'background.lastUpdate'.tr());
    } catch (_) {}
  }

  /// Service allaqachon ishlamoqda bo'lsa qayta boshlamaymiz.
  ///
  /// MUHIM (crash fix): foregroundServiceType manifest'da "location|dataSync".
  /// Android 14+ (API 34) da `location` tipidagi foreground service'ni
  /// joylashuv RUXSATISIZ ishga tushirish `SecurityException` (Foreground
  /// ServiceStartNotAllowed) beradi → ilova NATIVE crash bo'lib yopiladi
  /// ("onboarding/ruxsat oynasida chiqib ketyapti"). Shuning uchun joylashuv
  /// ruxsati berilmaguncha service'ni ISHGA TUSHIRMAYMIZ — ruxsat berilgach
  /// (PermissionsScreen) qayta chaqiriladi.
  Future<void> start() async {
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) return;

      // Joylashuv ruxsati gate — b'lmasa service'ni boshlamaymiz (crash oldini
      // olish). Restriction/Location service'larning 60s retry'i va ruxsat
      // ekranidagi qayta-start keyinroq uni yoqadi.
      final locGranted = await Permission.locationWhenInUse.isGranted;
      if (!locGranted) {
        debugPrint(
          '[BackgroundService] location ruxsati yo\'q — FGS start kechiktirildi',
        );
        return;
      }

      // BG isolate uchun tarjimani prefs'ga yozamiz (start'dan oldin — service
      // 60s ichida onRepeatEvent chaqirмасдан oldin tayyor bo'lsin).
      await _cacheNotifStrings();
      await FlutterForegroundTask.startService(
        notificationTitle: 'background.notificationTitle'.tr(),
        notificationText: 'background.notificationText'.tr(),
        callback: backgroundEntry,
      );
    } catch (e) {
      // Native xato (masalan FGS not allowed) Dart'ga PlatformException bo'lib
      // qaytsa shu yerda tutiladi — ilova crash bo'lmaydi.
      debugPrint('[BackgroundService] start() xato: $e');
    }
  }

  Future<void> stop() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) return;
    await FlutterForegroundTask.stopService();
  }
}
