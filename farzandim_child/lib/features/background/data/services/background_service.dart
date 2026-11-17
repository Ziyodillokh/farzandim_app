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
// yoqilgach service o'zi qayta ishga tushadi). Doimiy WakeLock/WifiLock
// YO'Q (BackgroundTaskConfig).
//
// Tarjimalar: easy_localization faqat UI isolate'da va FAQAT birinchi
// kadrdan keyin yuklanadi — undan oldin `.tr()` xom kalitni qaytaradi.
// Shuning uchun init() matnlarni keshlamaydi; UI tarjimalar yuklangach
// [cacheNotifStrings] ni chaqiradi (va `parvoz:strings` yuboradi). Kalitga
// teng qiymat HECH QACHON saqlanmaydi.
//
// iOS'da foreground service yo'q — barcha metodlar no-op.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/background/data/services/background_task_config.dart';
import 'package:farzandim_child/features/background/data/services/child_background_task_handler.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';

typedef Translate = String Function(String key);

class BackgroundService {
  /// Native block-overlay (RestrictionService) matnlari — native o'qiydi
  /// (`flutter.restriction.i18n.*`), yo'q bo'lsa o'zbekcha zaxira.
  static const overlayKeys = [
    'blocked',
    'limitReached',
    'blockedSub',
    'limitSub',
    'ok',
    'requestAccess',
    'timeRunningOut',
    'timeRunningOutBody',
    'schoolTitle',
    'schoolSub',
    'schoolSubNoTime',
    // RestrictionService bildirishnomalari (kanal, xizmat, ogohlantirish, ruxsat).
    'serviceChannel',
    'serviceChannelDesc',
    'serviceTitle',
    'serviceText',
    'warnChannel',
    'warnChannelDesc',
    'requestAccessTap',
  ];

  /// Notification kanali va options'ni sozlash. main.dart'dan chaqiriladi.
  /// Kanal nomi faqat tarjima qilingan bo'lsa, aks holda o'zbekcha zaxira.
  static void init({String? channelName}) {
    if (!PlatformCapabilities.hasForegroundService) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: BackgroundTaskConfig.channelId,
        channelName:
            channelName ??
            _translatedOr(
              'background.channelName',
              BackgroundTaskConfig.fallbackChannelName,
            ),
        channelDescription: _translatedOr(
          'background.channelDescription',
          BackgroundTaskConfig.fallbackChannelDescription,
        ),
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: BackgroundTaskConfig.taskOptions,
    );
  }

  /// UI tarjimalar yuklangach chaqiradi (ChildApp post-frame va til
  /// o'zgarganda): FGS bildirishnomasi va native overlay matnlarini prefs'ga
  /// yozadi. Tarjima yo'q (qiymat kalitga teng) — saqlanmaydi; eski xato
  /// yozuv (xom kalit) o'chiriladi. Keyin UI `parvoz:strings` yuboradi.
  /// [translate] — faqat testlar uchun (standart: `.tr()`).
  static Future<void> cacheNotifStrings({Translate? translate}) async {
    await _cacheNotifStrings(translate ?? _trKey);
  }

  /// `true` — kamida bitta qiymat o'zgardi.
  static Future<bool> _cacheNotifStrings(Translate translate) async {
    if (!PlatformCapabilities.hasForegroundService) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      var hasChanged = false;
      Future<void> put(String prefsKey, String trKey) async {
        final value = translate(trKey);
        if (value.isEmpty || value == trKey) {
          if (prefs.get(prefsKey) == trKey) {
            await prefs.remove(prefsKey);
            hasChanged = true;
          }
          return;
        }
        if (prefs.get(prefsKey) == value) return;
        await prefs.setString(prefsKey, value);
        hasChanged = true;
      }

      await put(
        BackgroundTaskConfig.prefsTitleKey,
        'background.notificationTitle',
      );
      await put(
        BackgroundTaskConfig.prefsTextKey,
        'background.notificationText',
      );
      await put(
        BackgroundTaskConfig.prefsChannelNameKey,
        'background.channelName',
      );
      for (final k in overlayKeys) {
        await put('restriction.i18n.$k', 'blockScreen.$k');
      }
      if (prefs.containsKey(BackgroundTaskConfig.legacyLastUpdateKey)) {
        await prefs.remove(BackgroundTaskConfig.legacyLastUpdateKey);
      }
      // Keyingi startService kanalni to'g'ri nom bilan yaratsin.
      final channelName = prefs.get(BackgroundTaskConfig.prefsChannelNameKey);
      if (channelName is String) init(channelName: channelName);
      return hasChanged;
    } catch (e) {
      debugPrint('[BackgroundService] matnlarni keshlash xato: $e');
      return false;
    }
  }

  /// Service allaqachon ishlamoqda bo'lsa qayta boshlamaymiz.
  ///
  /// Joylashuv ruxsati shart EMAS: vendored plagin FGS turini ish vaqtida
  /// tanlaydi (specialUse, location — faqat ruxsat bo'lsa), shuning uchun
  /// cheklov sync'i, heartbeat va o'yin xabarlari joylashuvsiz ham ishlaydi.
  Future<void> start() async {
    if (!PlatformCapabilities.hasForegroundService) return;
    try {
      final hasChanged = await _cacheNotifStrings(_trKey);
      if (await FlutterForegroundTask.isRunningService) {
        // Til o'zgargan bo'lsa ishlab turgan servis matnini yangilasin.
        if (hasChanged) {
          FlutterForegroundTask.sendDataToTask(ParvozMessages.strings);
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      // Kanal (birinchi startService'da yaratiladi) eng yaxshi nom bilan.
      init(
        channelName: _cachedOr(
          prefs,
          BackgroundTaskConfig.prefsChannelNameKey,
          'background.channelName',
          BackgroundTaskConfig.fallbackChannelName,
        ),
      );
      final result = await FlutterForegroundTask.startService(
        notificationTitle: _cachedOr(
          prefs,
          BackgroundTaskConfig.prefsTitleKey,
          'background.notificationTitle',
          BackgroundTaskConfig.fallbackTitle,
        ),
        notificationText: _cachedOr(
          prefs,
          BackgroundTaskConfig.prefsTextKey,
          'background.notificationText',
          BackgroundTaskConfig.fallbackText,
        ),
        callback: backgroundEntry,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('[BackgroundService] start() xato: ${result.error}');
      }
    } catch (e) {
      // Native xato (masalan FGS not allowed) Dart'ga PlatformException bo'lib
      // qaytsa shu yerda tutiladi — ilova crash bo'lmaydi.
      debugPrint('[BackgroundService] start() xato: $e');
    }
  }

  Future<void> stop() async {
    if (!PlatformCapabilities.hasForegroundService) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) return;
    await FlutterForegroundTask.stopService();
  }

  static String _trKey(String key) => key.tr();

  static String _translatedOr(String key, String fallback) {
    final value = key.tr();
    return value.isEmpty || value == key ? fallback : value;
  }

  /// Tarjima (yuklangan bo'lsa) → keshlangan qiymat → o'zbekcha zaxira.
  static String _cachedOr(
    SharedPreferences prefs,
    String prefsKey,
    String trKey,
    String fallback,
  ) {
    final translated = trKey.tr();
    if (translated.isNotEmpty && translated != trKey) return translated;
    final cached = prefs.get(prefsKey);
    if (cached is String && cached.isNotEmpty && cached != trKey) {
      return cached;
    }
    return fallback;
  }
}
