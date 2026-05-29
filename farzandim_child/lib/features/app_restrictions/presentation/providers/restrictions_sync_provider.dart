import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/restrictions_sync_service.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton — pairing tugagach `start(childId:)` chaqiriladi.
/// Backend **Schedule** (window-based BLOCK/ALLOW) + **AppLimit**
/// (per-package quota) ikkalasini parallel sync qiladi.
final restrictionsSyncServiceProvider =
    Provider<RestrictionsSyncService>((ref) {
  final service = RestrictionsSyncService(
    scheduleRepo: ref.watch(backendScheduleRepositoryProvider),
    appLimitRepo: ref.watch(backendAppLimitRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
