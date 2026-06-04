import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton — pairing tugagach `start(childId:)` chaqiriladi.
/// Backend **Schedule** (window BLOCK/ALLOW) + **AppLimit** (per-package
/// quota) + **Routine** ("Ilova cheklovlar" per-app) — uchchalasini sync.
final restrictionsSyncServiceProvider =
    Provider<RestrictionsSyncService>((ref) {
  final service = RestrictionsSyncService(
    scheduleRepo: ref.watch(backendScheduleRepositoryProvider),
    appLimitRepo: ref.watch(backendAppLimitRepositoryProvider),
    routineRepo: ref.watch(backendRoutineRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
