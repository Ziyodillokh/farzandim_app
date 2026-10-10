import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:farzandim_child/features/screen_time/data/ios_restrictions_sync_service.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton — pairing tugagach `start(childId:)` chaqiriladi.
/// Android: Backend **Schedule** (window BLOCK/ALLOW) + **AppLimit** (per-package
/// quota) + **Routine** ("Ilova cheklovlar" per-app) — uchchalasini sync.
/// iOS: Schedule BLOCK oynalari + "barcha ilovalarni bloklash" → Family
/// Controls (ilovalar tanlovi qurilmada, ota-ona tomonidan).
final restrictionsSyncServiceProvider = Provider<RestrictionsSync>((ref) {
  final RestrictionsSync service = PlatformCapabilities.isIOS
      ? IosRestrictionsSyncService(
          scheduleRepo: ref.watch(backendScheduleRepositoryProvider),
          devicePolicyRepo: ref.watch(backendDevicePolicyRepositoryProvider),
          channel: ref.watch(screenTimeChannelProvider),
        )
      : RestrictionsSyncService(
          scheduleRepo: ref.watch(backendScheduleRepositoryProvider),
          appLimitRepo: ref.watch(backendAppLimitRepositoryProvider),
          routineRepo: ref.watch(backendRoutineRepositoryProvider),
          devicePolicyRepo: ref.watch(backendDevicePolicyRepositoryProvider),
        );
  ref.onDispose(service.dispose);
  return service;
});
