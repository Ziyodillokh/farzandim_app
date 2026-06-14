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

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:farzandim_child/features/background/data/services/child_background_task_handler.dart';

class BackgroundService {
  /// Notification kanali va options'ni sozlash. main.dart'dan chaqiriladi.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'farzandim_child_bg',
        channelName: 'Parvoz xizmati',
        channelDescription:
            "Bola joylashuvini va holatini doimiy kuzatish uchun",
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

      await FlutterForegroundTask.startService(
        notificationTitle: 'Parvoz ishlayapti',
        notificationText: "Oilangiz bilan bog'liqsiz",
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
