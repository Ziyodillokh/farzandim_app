// ─────────────────────────────────────────────────────────────────────
// IosRestrictionsSyncService — ota-ona siyosatini Family Controls'ga
// ─────────────────────────────────────────────────────────────────────
//
// Backend'dan faqat ilova-nomisiz siyosat olinadi (BLOCK jadvallar +
// "barcha ilovalarni bloklash") va native tomonga beriladi. Jadval
// chegaralarida cheklovni ParvozMonitor kengaytmasi o'zi yoqib-o'chiradi —
// ilova yopiq bo'lsa ham. iOS'da ilovalar ro'yxati/usage HECH QACHON
// serverga yuborilmaydi.
//
// FAIL-CLOSED: tarmoq xatosida oxirgi siyosat o'zgarmaydi (Android bilan
// bir xil) — aviarejim cheklovni o'chirib yubormasin.
//
// Qo'shimcha vaqt: ota-ona tasdiqlagan grant (`GET /unlock-requests/active`)
// native'ga beriladi — u tugaganda kengaytma cheklovni o'zi qaytaradi.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:farzandim_child/features/screen_time/domain/ios_shield_policy.dart';

class IosRestrictionsSyncService implements RestrictionsSync {
  IosRestrictionsSyncService({
    required BackendScheduleRepository scheduleRepo,
    required BackendDevicePolicyRepository devicePolicyRepo,
    required BackendUnlockRequestRepository unlockRepo,
    required ScreenTimeChannel channel,
    DateTime Function()? clock,
  })  : _scheduleRepo = scheduleRepo,
        _devicePolicyRepo = devicePolicyRepo,
        _unlockRepo = unlockRepo,
        _channel = channel,
        _clock = clock ?? DateTime.now;

  /// Ilova ochiq paytdagi davriy yangilash. Ilova yopiq bo'lsa jadvallarni
  /// kengaytma bajaradi, "darhol bloklash" esa WS/push bilan keladi.
  static const syncInterval = Duration(seconds: 60);
  static const _prefsKeyBlockAllCache = 'screenTime.blockAllCache.v1';

  /// easy_localization tanlangan tilni shu kalitda saqlaydi ("uz", "ru_RU").
  static const _prefsKeyLocale = 'locale';

  final BackendScheduleRepository _scheduleRepo;
  final BackendDevicePolicyRepository _devicePolicyRepo;
  final BackendUnlockRequestRepository _unlockRepo;
  final ScreenTimeChannel _channel;
  final DateTime Function() _clock;
  Timer? _timer;
  String? _childId;

  /// Native'ga oxirgi berilgan grant oxiri; `null` — grant yo'q (yoki hali
  /// bilinmaydi: start'dan keyin birinchi sync eski holatni tozalaydi).
  DateTime? _appliedUnlockUntil;
  bool _unlockStateKnown = false;

  @override
  void start({required String childId}) {
    _childId = childId;
    _unlockStateKnown = false;
    _timer?.cancel();
    unawaited(sync());
    _timer = Timer.periodic(syncInterval, (_) => unawaited(sync()));
  }

  @override
  Future<void> sync() async {
    final childId = _childId;
    if (childId == null) return;
    try {
      final schedules = await _scheduleRepo.getSchedules(childId);
      if (schedules == null) {
        debugPrint("IosRestrictionsSync: tarmoq yo'q — oxirgi siyosat saqlanadi");
        return;
      }
      final devicePolicy = await _devicePolicyRepo.getDevicePolicy(childId);
      final blockAll = await _resolveBlockAll(devicePolicy.blockAllApps);
      final policy = IosShieldPolicy.fromBackend(
        schedules: schedules,
        blockAll: blockAll,
      );
      final prefs = await SharedPreferences.getInstance();
      final isBlocking = await _channel.applyPolicy(
        policy,
        languageCode: prefs.getString(_prefsKeyLocale)?.split('_').first,
      );
      await _syncUnlock();
      debugPrint(
        'IosRestrictionsSync: windows=${policy.windows.length} '
        'blockAll=$blockAll blocking=$isBlocking',
      );
    } catch (e) {
      debugPrint('IosRestrictionsSync xato: $e');
    }
  }

  /// Ota-ona tasdiqlagan qo'shimcha vaqt → native. So'rov yiqilsa holat
  /// o'zgarmaydi; o'zgarmagan grant qayta yuborilmaydi.
  Future<void> _syncUnlock() async {
    final grants = await _unlockRepo.getActiveGrants();
    if (grants == null) return;
    final now = _clock();
    final active = grants.where((g) => g.expiresAt.isAfter(now)).toList();
    if (active.isEmpty) {
      if (_unlockStateKnown && _appliedUnlockUntil == null) return;
      await _channel.clearUnlock();
      _appliedUnlockUntil = null;
      _unlockStateKnown = true;
      return;
    }
    final latest = active.reduce(
      (a, b) => a.expiresAt.isAfter(b.expiresAt) ? a : b,
    );
    if (_unlockStateKnown && _appliedUnlockUntil == latest.expiresAt) return;
    final minutes = (latest.expiresAt.difference(now).inSeconds / 60).ceil();
    await _channel.grantUnlock(
      until: latest.expiresAt,
      minutes: minutes < 1 ? 1 : minutes,
    );
    _appliedUnlockUntil = latest.expiresAt;
    _unlockStateKnown = true;
  }

  /// Qurilma-siyosati so'rovi alohida yiqilsa (`null`) — oxirgi ma'lum
  /// qiymat, aks holda "hammasini bloklash" tarmoq uzilishida o'chib qolardi.
  Future<bool> _resolveBlockAll(bool? fetched) async {
    final prefs = await SharedPreferences.getInstance();
    if (fetched != null) {
      await prefs.setBool(_prefsKeyBlockAllCache, fetched);
      return fetched;
    }
    return prefs.getBool(_prefsKeyBlockAllCache) ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
