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

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:farzandim_child/features/background/data/services/child_background_task_handler.dart';

class BackgroundService {
  /// Notification kanali va options'ni sozlash. main.dart'dan chaqiriladi.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'farzandim_child_bg',
        channelName: 'Farzandim Child Service',
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
  Future<void> start() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) return;

    // foregroundServiceType "location|dataSync" sifatida AndroidManifest'da
    // override qilingan — package'ning 8.17 API'sida serviceTypes parametri
    // yo'q, manifest orqali sozlanadi.
    await FlutterForegroundTask.startService(
      notificationTitle: 'Farzandim ishlayapti',
      notificationText: "Oilangiz bilan bog'liqsiz",
      callback: backgroundEntry,
    );
  }

  Future<void> stop() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) return;
    await FlutterForegroundTask.stopService();
  }
}
