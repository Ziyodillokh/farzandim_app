// ─────────────────────────────────────────────────────────────────────
// ParvozMessages — fon servisi (FGS isolate) qabul qiladigan xabarlar
// ─────────────────────────────────────────────────────────────────────
//
// Native (ForegroundService.sendData) va UI isolate
// (FlutterForegroundTask.sendDataToTask) shu satrlarni yuboradi;
// ChildBackgroundTaskHandler.onReceiveData → BackgroundJobs.onMessage.
// Satrlar native bilan kontrakt — o'zgartirmang.

abstract final class ParvozMessages {
  /// 5 daqiqalik alarm (native BootReceiver, 30 s vaqtli wakelock bilan).
  static const tick = 'parvoz:tick';

  /// Ekran yoqildi / qulf ochildi (native RestrictionService).
  static const screenOn = 'parvoz:screen_on';

  /// Cheklovlar o'zgardi: FCM `restrictions_sync` / `unlock_decision`,
  /// UI isolate'dagi WS hodisalari.
  static const restrictionsSync = 'parvoz:restrictions_sync';

  /// Ota-ona xaritani ochdi (FCM `location_wake`).
  static const locationWake = 'parvoz:location_wake';

  /// UI isolate tarjimalarni prefs'ga yozdi — bildirishnoma yangilansin.
  static const strings = 'parvoz:strings';
}
