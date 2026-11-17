// ─────────────────────────────────────────────────────────────────────
// BackgroundTaskConfig — foreground service sozlamalari (yagona manba)
// ─────────────────────────────────────────────────────────────────────
//
// UI isolate (startService) va FGS isolate (onStart'da plagin saqlagan
// eski sozlamani yangilash) shu yerdan oladi. Eski versiyalar doimiy
// WakeLock + WifiLock va 60 s repeat bilan saqlangan — tizim servisni
// (boot / yangilanish / qayta ishga tushirish) shu saqlangan sozlama bilan
// ko'taradi, shuning uchun FGS isolate uni bir marta yangilab qo'yadi.

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

abstract final class BackgroundTaskConfig {
  static const channelId = 'farzandim_child_bg';

  /// onRepeatEvent — faqat qurilma uyg'oq paytda zaxira tick. Asosiy tick —
  /// native 5 daqiqalik alarm (`parvoz:tick`), u telefonni o'zi uyg'otadi.
  static const repeatIntervalMs = 5 * 60 * 1000;

  /// Doimiy WakeLock/WifiLock YO'Q — telefon uxlashi kerak (batareya).
  static ForegroundTaskOptions get taskOptions => ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(repeatIntervalMs),
    autoRunOnBoot: true,
    autoRunOnMyPackageReplaced: true,
    allowWakeLock: false,
    allowWifiLock: false,
  );

  // Bildirishnoma matnlari — UI isolate tarjima qilib shu kalitlarga yozadi
  // (FGS isolate'da easy_localization yo'q).
  static const prefsTitleKey = 'bg.notifTitle';
  static const prefsTextKey = 'bg.notifText';
  static const prefsChannelNameKey = 'bg.channelName';

  /// Eski versiyaning har daqiqalik "Oxirgi yangilanish" shabloni — endi
  /// ishlatilmaydi, tozalanadi.
  static const legacyLastUpdateKey = 'bg.lastUpdateTpl';

  // Tarjima hali yuklanmagan bo'lsa — o'zbekcha zaxira (xom kalit EMAS).
  static const fallbackTitle = 'Parvoz ishlayapti';
  static const fallbackText = 'Joylashuv va faollik kuzatilmoqda';
  static const fallbackChannelName = 'Parvoz xizmati';
  static const fallbackChannelDescription =
      'Bola joylashuvini va holatini doimiy kuzatish uchun';
}
