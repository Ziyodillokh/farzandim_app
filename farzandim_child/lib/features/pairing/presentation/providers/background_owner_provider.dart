// ─────────────────────────────────────────────────────────────────────
// backgroundOwnerProvider — BackgroundOwner'ni haqiqiy platformaga ulaydi
// ─────────────────────────────────────────────────────────────────────
//
// Android: FGS (flutter_foreground_task), native RestrictionService
// (UsageStatsPlugin kanali) va UI isolate uchun BackgroundJobs (C1b).
// iOS: FGS yo'q — UI isolate BackgroundJobs'ga ega, cheklovlar esa
// IosRestrictionsSyncService (restrictionsSyncServiceProvider) yo'lida.
//
// Qadamlar (StepCounterService) — UI isolate'da: Health Connect ruxsati va
// o'qish ilova ekranda bo'lishini talab qiladi, FGS isolate'i qadamlarni
// yuritmaydi. UI egasi bo'lsa BackgroundJobs tick'i `syncIfDue` qiladi,
// ilova fondan qaytganda `syncNow` (davriy taymer yo'q).
//
// Provider qurilma egasining (asosiy) konteynerida PairingNotifier bilan
// birga yashaydi; ilova fondan qaytganda egalik qayta tekshiriladi.

import 'dart:async';

import 'package:farzandim_child/app/app_lifecycle_provider.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/background/data/services/background_jobs.dart';
import 'package:farzandim_child/features/background/data/services/background_service.dart';
import 'package:farzandim_child/features/background/presentation/providers/background_service_provider.dart';
import 'package:farzandim_child/features/pairing/data/services/background_owner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backgroundOwnerProvider = Provider<BackgroundOwner>((ref) {
  final owner = BackgroundOwner(
    usesForegroundService: PlatformCapabilities.hasForegroundService,
    platform: _AppBackgroundPlatform(ref.read(backgroundServiceProvider)),
    createJobs: (session) => _UiBackgroundJobs(
      BackgroundJobs(
        childId: session.childId,
        parentUid: session.parentUid,
        childName: session.childName,
        // Juftlangandan keyin chaqiriladi — provider shu bolaniki.
        stepCounter: ref.read(stepCounterServiceProvider),
      ),
    ),
    syncRestrictionsInUi: PlatformCapabilities.isIOS
        ? () => ref.read(restrictionsSyncServiceProvider).sync()
        : null,
  );
  // Ekranga qaytish (jumladan Sozlamalarda ruxsat berib qaytish yoki tizim
  // ruxsat dialogi yopilishi): FGS va native bloklash shu zahoti yoqiladi,
  // UI egasi bo'lsa yetishmagan ishlar bajariladi. Binding oraliq holatlarni
  // ham beradi (paused → hidden → inactive → resumed) — fonda bo'lgani
  // alohida eslab qolinadi.
  var wasInBackground = false;
  ref.listen<AppLifecycleState>(appLifecycleProvider, (previous, next) {
    if (!isForegroundState(next)) {
      wasInBackground = true;
      return;
    }
    if (next != AppLifecycleState.resumed ||
        previous == AppLifecycleState.resumed) {
      return;
    }
    unawaited(owner.onResume());
    if (!wasInBackground) return;
    wasInBackground = false;
    // Fondan qaytdi (dialog emas) — ekrandagi qadamlar yangilansin.
    if (owner.session == null) return;
    final steps = ref.read(stepCounterServiceProvider);
    if (steps != null) unawaited(steps.syncNow());
  });
  ref.onDispose(owner.dispose);
  return owner;
});

class _UiBackgroundJobs implements BackgroundJobsHandle {
  _UiBackgroundJobs(this._jobs);

  final BackgroundJobs _jobs;

  @override
  Future<void> start() => _jobs.start();

  @override
  Future<void> stop() => _jobs.stop();

  @override
  Future<void> onTick() => _jobs.onTick();

  @override
  Future<void> onScreenOn() => _jobs.onScreenOn();

  @override
  Future<void> onMessage(String type) => _jobs.onMessage(type);

  @override
  Future<void> onConnectivityRestored() => _jobs.onConnectivityRestored();
}

class _AppBackgroundPlatform implements BackgroundPlatform {
  _AppBackgroundPlatform(this._service);

  final BackgroundService _service;
  final UsageStatsService _usage = UsageStatsService();

  @override
  Future<bool> isServiceRunning() => FlutterForegroundTask.isRunningService;

  @override
  Future<void> startService() => _service.start();

  @override
  void sendToService(String message) =>
      FlutterForegroundTask.sendDataToTask(message);

  /// RestrictionService faqat usage ruxsati bilan ham ishlaydi: o'yin
  /// aniqlash overlay talab qilmaydi, overlay ruxsati bo'lmasa bloklash
  /// oynasi o'zi no-op. Servis start idempotent (native isRunning guard).
  @override
  Future<void> startEnforcement() async {
    if (!PlatformCapabilities.hasAndroidControls) return;
    if (!await _usage.hasPermission()) return;
    await _usage.startRestrictionService();
  }
}
