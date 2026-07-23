// ─────────────────────────────────────────────────────────────────────
// ChildBackgroundTaskHandler — Foreground Service ichida ishlovchi Dart
// ─────────────────────────────────────────────────────────────────────
//
// flutter_foreground_task ilovaning asosiy isolate'idan alohida
// isolate'da bu kodni ishga tushiradi. Shu sababli:
//   - Firebase'ni qayta init qilish kerak (har isolate'da alohida).
//   - SharedPreferences'dan parentUid/childId tiklab olamiz.
//   - DeviceInfoService va LocationService klasslari isolate-agnostic
//     (har biri o'z FirebaseFirestore.instance'idan foydalanadi).
//
// Eslatma: `backgroundEntry` top-level + @pragma('vm:entry-point') —
// Flutter Engine isolate'ni boshlash uchun shu shartlarni qo'yadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/offline/offline_buffer.dart';
import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/game_report_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_sync_service.dart';
import 'package:farzandim_child/features/device_info/data/services/device_info_service.dart';
import 'package:farzandim_child/features/location/data/services/location_service.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/firebase_options.dart';

@pragma('vm:entry-point')
void backgroundEntry() {
  FlutterForegroundTask.setTaskHandler(ChildBackgroundTaskHandler());
}

class ChildBackgroundTaskHandler extends TaskHandler {
  // Services field initializer'da yaratilmaydi — chunki ular
  // FirebaseFirestore.instance'ga murojaat qiladi va BG isolate'da
  // Firebase hali init qilinmagan bo'ladi. onStart()'dan keyin yaratamiz.
  DeviceInfoService? _deviceInfoService;
  LocationService? _locationService;
  UsageSyncService? _usageSyncService;
  RestrictionsSyncService? _restrictionsSyncService;
  GameReportService? _gameReportService;
  // Offline buffer flush — ASOSIY enqueue shu bg isolate'da bo'ladi
  // (LocationService). UI isolate'dagi flusher bg yozganini ko'rmasdi;
  // endi flush shu yerda ham har 60s ishlaydi (start() chaqirmaymiz —
  // ikkinchi Connectivity stream ochilmasin).
  OfflineBuffer? _offlineBuffer;

  String? _parentUid;
  String? _childId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 1. Yangi isolate'da Firebase init majburiy. Bu birinchi qadam —
    // undan oldin hech qanday FirebaseFirestore.instance ishlatilmaydi.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // App allaqachon initialised — qaytarib o'rinish kerak emas.
    }

    // 2. Pairing ma'lumotini SharedPreferences'dan olish.
    final prefs = await SharedPreferences.getInstance();
    _parentUid = prefs.getString('parentUid');
    _childId = prefs.getString('childId');
    final childName = prefs.getString('childName') ?? 'Bola';

    if (_parentUid == null || _childId == null) {
      // Pair'lashmagan — service'ni to'xtatamiz.
      FlutterForegroundTask.stopService();
      return;
    }

    // 3. Endi Firebase tayyor — service instance'larini yaratamiz va
    // ishga tushiramiz.
    _deviceInfoService = DeviceInfoService();
    _locationService = LocationService();

    await _deviceInfoService!.start(parentUid: _parentUid!, childId: _childId!);
    await _locationService!.start(
      parentUid: _parentUid!,
      childId: _childId!,
      childName: childName,
    );

    // Foydalanish (faollik) sync'i — background isolate'da ham ishlaydi, shu
    // sababli ilova fonda bo'lsa ham ekran vaqti ~1 daqiqada yangilanadi
    // (avval faqat UI isolate'da edi → ilova yopilsa faollik kechikardi).
    _usageSyncService = UsageSyncService(
      backendRepo: BackendInstalledAppsRepository(
        dio: createBackendDio(TokenStorage()),
      ),
      statsService: UsageStatsService(),
      childId: _childId!,
    )..start();

    // Cheklov sync (jadval oynasi + app-limit) — background isolate'da ham
    // ishlaydi, shu sababli bola BOSHQA ilova ishlatganda (farzandim fonda)
    // ham jadval bloklari yangilanadi. Native RestrictionService prefs'ni
    // o'qib enforce qiladi.
    _restrictionsSyncService = RestrictionsSyncService(
      scheduleRepo: BackendScheduleRepository(
        dio: createBackendDio(TokenStorage()),
      ),
      appLimitRepo: BackendAppLimitRepository(
        dio: createBackendDio(TokenStorage()),
      ),
      routineRepo: BackendRoutineRepository(
        dio: createBackendDio(TokenStorage()),
      ),
      devicePolicyRepo: BackendDevicePolicyRepository(
        dio: createBackendDio(TokenStorage()),
      ),
    )..start(childId: _childId!);

    // O'yin (CATEGORY_GAME) ochilganini kuzatish — onRepeatEvent har ~60s
    // check() chaqiradi → yangi o'yin ochilsa ota-onaga push ("o'ynayapti"
    // + Bloklash). Native faqat o'yinlarni filtrlaydi.
    _gameReportService = GameReportService(childId: _childId!);

    // Offline buffer — bg isolate'da ham flush (asosiy enqueue shu yerda).
    _offlineBuffer = OfflineBuffer();

    // FCM token'ni backend'ga QAYTA ro'yxatdan o'tkazamiz. Birinchi pair'da
    // UI isolate init() JWT'dan oldin ishlab token yetmagan bo'lishi mumkin
    // (register 401 -> backend'da token yo'q -> "Baland ovoz" ring sent:0
    // jim no-op). Bu yer pair'dan keyin VA har ishga tushganda ishlaydi.
    unawaited(
      FcmService(
        backendRepo: BackendFcmRepository(
          dio: createBackendDio(TokenStorage()),
        ),
      ).refreshRegistration(),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Kafolatlangan device-info heartbeat (har 60s, foreground service bilan).
    // Ichki 20s timer ishlamay qolsa ham qurilma online qoladi va batareya/
    // zaryadlanish yangilanadi (token avtomatik refresh bo'ladi).
    unawaited(_deviceInfoService?.ping() ?? Future<void>.value());

    // O'yin ochilganini tekshirish (faqat o'yinlar → ota-onaga push).
    unawaited(_gameReportService?.check() ?? Future<void>.value());

    // Offline buffer flush — net qaytgan bo'lsa yig'ilganlarni yuborish
    // (flush o'zi connectivity tekshiradi, bo'sh bufferda tez no-op).
    unawaited(_offlineBuffer?.flush() ?? Future<void>.value());

    // Notification matnini yangilash — foydalanuvchi service ishlayotganini
    // ko'radi. ⚠️ Bu KOD BG ISOLATE'da ishlaydi — easy_localization u yerda
    // yuklanmagan, `.tr()` XOM KALIT qaytaradi ("background.notificationTitle"
    // ko'rinardi). Shu sabab main isolate SharedPreferences'ga yozgan tarjimani
    // reload bilan o'qiymiz (BackgroundService._cacheNotifStrings).
    final timeStr = DateFormat('HH:mm').format(toTashkent(timestamp));
    unawaited(_updateNotification(timeStr));
  }

  Future<void> _updateNotification(String timeStr) async {
    var title = 'Parvoz';
    var text = timeStr;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Main isolate yozgan yangi qiymatlarni ko'rish uchun reload SHART
      // (SharedPreferences har isolate'da alohida keshlanadi).
      await prefs.reload();
      title = prefs.getString('bg.notifTitle') ?? title;
      final tpl = prefs.getString('bg.lastUpdateTpl');
      if (tpl != null) text = tpl.replaceAll('{time}', timeStr);
    } catch (_) {}
    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _deviceInfoService?.stop();
    _locationService?.stop();
    _usageSyncService?.dispose();
    _restrictionsSyncService?.dispose();
  }

  @override
  void onReceiveData(Object data) {
    // Asosiy isolate'dan keladigan xabarlar (kelajakda ishlatish uchun
    // qoldirildi — masalan, notification tugmasi yoki SOS trigger).
    debugPrint('BG handler received data: $data');
  }

  @override
  void onNotificationPressed() {
    // Foydalanuvchi notificationga bossa — ilovani ochamiz.
    FlutterForegroundTask.launchApp();
  }
}
