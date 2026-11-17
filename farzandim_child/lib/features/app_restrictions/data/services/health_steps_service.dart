// ─────────────────────────────────────────────────────────────────────
// HealthStepsService — bugungi qadam jami (Health Connect)
// ─────────────────────────────────────────────────────────────────────
//
// NEGA KERAK: Android qadam sensori (pedometer / TYPE_STEP_COUNTER) faqat
// "telefon yoqilgandan beri JAMI" ni beradi — "bugun nechta" degan ma'lumot
// yo'q. Shuning uchun ilova birinchi o'qishda "nol nuqta" qo'yib, faqat
// SHUNDAN KEYINGI qadamlarni sanaydi: bugun ilova kuzatuvni boshlagunga
// qadar yurilgan qadamlar YO'QOLADI (telefonda 932, ilovada 200 ko'rinardi).
//
// Health Connect esa butun kunning jamini beradi va Samsung Health ham
// aynan shu yerga yozadi → ilovadagi son telefondagi son bilan MOS keladi.
//
// Health Connect bo'lmasa yoki ruxsat berilmasa — `null` qaytadi va
// chaqiruvchi (StepCounterService) pedometer hisobiga qaytadi (fallback).
//
// iOS: Health Connect o'rniga CoreMotion (`CMPedometer`, native
// MotionStepsPlugin) — HealthKit entitlement'siz bugungi jamini beradi.
// Ruxsat — Motion & Fitness (`Permission.sensors`).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';

class HealthStepsService {
  HealthStepsService._();

  /// Yagona instance — configure() bir marta chaqirilishi uchun.
  static final HealthStepsService instance = HealthStepsService._();

  final Health _health = Health();
  bool _configured = false;
  bool? _available;

  /// iOS native kanal — ios/Runner/MotionStepsPlugin.swift.
  static const MethodChannel _motion = MethodChannel('uz.parvoz.growth/motion');

  static const List<HealthDataType> _types = [HealthDataType.STEPS];
  static const List<HealthDataAccess> _perms = [HealthDataAccess.READ];

  /// Testlar uchun — keshlangan mavjudlik natijasini tozalaydi.
  @visibleForTesting
  void debugReset() => _available = null;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Qadam manbai shu qurilmada mavjudmi (Android — Health Connect SDK,
  /// iOS — CoreMotion qadam sanog'i). Natija keshlanadi.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    final cached = _available;
    if (cached != null) return cached;
    try {
      if (PlatformCapabilities.isIOS) {
        _available = await _motion.invokeMethod<bool>('isAvailable') ?? false;
        return _available!;
      }
      if (!PlatformCapabilities.hasHealthConnect) {
        _available = false;
        return false;
      }
      await _ensureConfigured();
      final status = await _health.getHealthConnectSdkStatus();
      _available = status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('HealthSteps: SDK status xato: $e');
      _available = false;
    }
    return _available ?? false;
  }

  /// Qadamni o'qish ruxsati bormi (so'ramaydi).
  Future<bool> hasPermission() async {
    if (!await isAvailable()) return false;
    try {
      if (PlatformCapabilities.isIOS) return await Permission.sensors.isGranted;
      return await _health.hasPermissions(_types, permissions: _perms) ?? false;
    } catch (e) {
      debugPrint('HealthSteps: hasPermissions xato: $e');
      return false;
    }
  }

  /// Ruxsat so'rash — Health Connect ruxsat ekranini ochadi. Allaqachon
  /// berilgan bo'lsa ekran chiqmaydi.
  Future<bool> requestPermission() async {
    if (!await isAvailable()) return false;
    try {
      if (await hasPermission()) return true;
      if (PlatformCapabilities.isIOS) {
        return await Permission.sensors.request().isGranted;
      }
      return await _health.requestAuthorization(_types, permissions: _perms);
    } catch (e) {
      debugPrint('HealthSteps: requestAuthorization xato: $e');
      return false;
    }
  }

  /// BUGUNGI jami qadam (mahalliy yarim tundan hozirgacha) — telefon
  /// ko'rsatadigan son bilan bir xil. Ruxsat/HC yo'q bo'lsa `null`.
  Future<int?> stepsForToday() async {
    if (!await hasPermission()) return null;
    try {
      final now = DateTime.now();
      // Kun boshi — UTC+5 (Toshkent) yarim tuni, StepCounterService va
      // backend (`tashkentDayKey`) bilan AYNAN bir xil chegara.
      //
      // ⚠️ Avval `DateTime(now.year, now.month, now.day)` — qurilma LOKAL
      // yarim tuni ishlatilardi. Qurilma vaqt mintaqasi UTC+5 bo'lmasa (yoki
      // avtomatik TZ noto'g'ri bo'lsa) HC oynasi ilovaning "bugun"idan farq
      // qilib, qadam soni mos kelmasdi.
      final tashkentNow = now.toUtc().add(const Duration(hours: 5));
      final start = DateTime.utc(
        tashkentNow.year,
        tashkentNow.month,
        tashkentNow.day,
      ).subtract(const Duration(hours: 5)).toLocal();
      final total = PlatformCapabilities.isIOS
          ? await _motion.invokeMethod<int>('stepsBetween', {
              'startMs': start.millisecondsSinceEpoch,
              'endMs': now.millisecondsSinceEpoch,
            })
          : await _health.getTotalStepsInInterval(start, now);
      if (total == null || total < 0) return null;
      return total;
    } catch (e) {
      debugPrint('HealthSteps: bugungi qadamni o\'qish xato: $e');
      return null;
    }
  }
}
