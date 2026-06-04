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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_fcm_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/fcm_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_sync_service.dart';
import 'package:farzandim_child/features/device_info/data/services/device_info_service.dart';
import 'package:farzandim_child/features/location/data/services/location_service.dart';
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

    await _deviceInfoService!.start(
      parentUid: _parentUid!,
      childId: _childId!,
    );
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

    // FCM token'ni backend'ga QAYTA ro'yxatdan o'tkazamiz. Birinchi pair'da
    // UI isolate init() JWT'dan oldin ishlab token yetmagan bo'lishi mumkin
    // (register 401 -> backend'da token yo'q -> "Baland ovoz" ring sent:0
    // jim no-op). Bu yer pair'dan keyin VA har ishga tushganda ishlaydi.
    unawaited(
      FcmService(
        backendRepo: BackendFcmRepository(dio: createBackendDio(TokenStorage())),
      ).refreshRegistration(),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Kafolatlangan device-info heartbeat (har 60s, foreground service bilan).
    // Ichki 20s timer ishlamay qolsa ham qurilma online qoladi va batareya/
    // zaryadlanish yangilanadi (token avtomatik refresh bo'ladi).
    unawaited(_deviceInfoService?.ping() ?? Future<void>.value());

    // Notification matnini yangilash — foydalanuvchi service ishlayotganini
    // ko'radi. ForegroundTaskOptions.repeat(60000) ga moslangan.
    final timeStr = DateFormat('HH:mm').format(timestamp);
    FlutterForegroundTask.updateService(
      notificationTitle: 'Farzandim ishlayapti',
      notificationText: "Oxirgi yangilanish: $timeStr",
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _deviceInfoService?.stop();
    _locationService?.stop();
    _usageSyncService?.dispose();
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
