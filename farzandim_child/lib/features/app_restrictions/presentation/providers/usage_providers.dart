// ─────────────────────────────────────────────────────────────────────
// usage_providers — Riverpod state grafi (Sprint 4.4.10 Backend)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/step_counter_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_sync_service.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

final usageStatsServiceProvider = Provider<UsageStatsService>((ref) {
  return UsageStatsService();
});

final usagePermissionProvider = FutureProvider<bool>((ref) async {
  return ref.read(usageStatsServiceProvider).hasPermission();
});

/// Pairing'ga bog'liq — pair'lashmagan bo'lsa null.
/// Sync timer'i sifatida ishlatish uchun caller `start()` chaqiradi.
///
/// **Sprint 4.2 bugfix:** `ref.watch(pairingStateProvider)` ishlatilsa
/// PairingNotifier ichidan `ref.read(usageSyncServiceProvider)` chaqirish
/// `CircularDependencyError` keltirib chiqaradi (Riverpod ofes). `ref.read`
/// ishlatamiz — bu provider faqat bir marta yaratilganda pair holatini
/// o'qiydi, keyingi pair o'zgarishlariga reaktsiya qilmaydi (lekin biz
/// uni faqat pair tugagandan keyin chaqiramiz, shuning uchun muammo yo'q).
final usageSyncServiceProvider = Provider<UsageSyncService?>((ref) {
  final pairing = ref.read(pairingStateProvider);
  if (pairing.childId == null) return null;

  final stats = ref.read(usageStatsServiceProvider);
  final backendRepo = ref.read(backendInstalledAppsRepositoryProvider);

  final service = UsageSyncService(
    backendRepo: backendRepo,
    statsService: stats,
    childId: pairing.childId!,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Qadam sanagich — pair'lashmagan bo'lsa null. `start()` pairing flow'da
/// usageSync bilan birga chaqiriladi (foreground sensor stream).
final stepCounterServiceProvider = Provider<StepCounterService?>((ref) {
  final pairing = ref.read(pairingStateProvider);
  if (pairing.childId == null) return null;

  final backendRepo = ref.read(backendInstalledAppsRepositoryProvider);
  final service = StepCounterService(
    backendRepo: backendRepo,
    childId: pairing.childId!,
  );
  ref.onDispose(service.dispose);
  return service;
});
