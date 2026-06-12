// ─────────────────────────────────────────────────────────────────────
// app_usage_providers — Backend (Sprint 4.4.24)
// ─────────────────────────────────────────────────────────────────────
//
// Backend `0.5.1` LIVE — per-app limit endpoint mavjud. Stub olib
// tashlandi, real Backend repository ulandi.

import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun bugungi foydalanish — Backend fetch + 30 sek polling.
///
/// Backend hozir `app_usage:updated` WS event emit qilmaydi —
/// vaqtinchalik polling bilan ushlaymiz (`pollFetchStream` skaffoldi).
/// `autoDispose` + 2 daq keep-alive (P0-1): ekran yopilgach polling
/// TO'XTAYDI, tez qaytishda loading "flash" yo'q.
final todayUsageProvider = StreamProvider.autoDispose
    .family<AppUsageDay?, String>((ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield null;
    return;
  }
  keepAliveFor(ref, const Duration(minutes: 2));
  final repo = ref.watch(backendAppUsageRepositoryProvider);
  yield* pollFetchStream<AppUsageDay?>(
    ref,
    interval: const Duration(seconds: 30),
    fetch: () => repo.getTodayUsage(childId),
  );
});

/// Bola qurilmasidagi o'rnatilgan ilovalar — Backend fetch + 60s polling
/// (yangi pair qilingan qurilmada nomlar/ikonalar tez kelishi uchun).
/// `autoDispose` + 2 daq keep-alive (P0-1, yuqoridagi kabi).
final installedAppsProvider = StreamProvider.autoDispose
    .family<List<AppUsageEntry>, String>((ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield const <AppUsageEntry>[];
    return;
  }
  keepAliveFor(ref, const Duration(minutes: 2));
  final repo = ref.watch(backendAppUsageRepositoryProvider);
  yield* pollFetchStream<List<AppUsageEntry>>(
    ref,
    interval: const Duration(seconds: 60),
    fetch: () => repo.getInstalledApps(childId: childId),
    // NET-07 (SWR): keshdagi ro'yxat DARHOL — ekran spinner'da turmaydi.
    readCache: () async {
      final cached = await repo.getCachedInstalledApps(childId);
      return (cached != null && cached.isNotEmpty) ? cached : null;
    },
  );
});

/// Bola uchun cheklovlar — Backend `/app-limits` orqali (0.5.1).
final restrictionsProvider =
    StreamProvider.family<List<AppRestriction>, String>(
        (ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield const <AppRestriction>[];
    return;
  }
  final repo = ref.watch(backendAppLimitRepositoryProvider);
  yield await repo.getRestrictions(childId);
});

/// AppLimit Backend repository — UI'da chaqirilgan stub o'rniga.
///
/// Mapping (UI semantikasi → Backend):
///   - Block       → upsert(dailyLimitMs: 0)
///   - Limit X min → upsert(dailyLimitMs: X * 60000)
///   - Remove      → DELETE /app-limits/:id
class _AppLimitFacade {
  _AppLimitFacade(this._ref);
  final Ref _ref;

  BackendAppLimitRepository get _repo =>
      _ref.read(backendAppLimitRepositoryProvider);

  Future<void> blockApp({
    required String childId,
    required String packageName,
    required String appName,
    int? durationMinutes,
  }) async {
    await _repo.upsert(
      childId: childId,
      packageName: packageName,
      appName: appName,
      dailyLimitMs: 0,
    );
    _ref.invalidate(restrictionsProvider(childId));
  }

  Future<void> setLimit({
    required String childId,
    required String packageName,
    required String appName,
    required int limitMinutes,
  }) async {
    await _repo.upsert(
      childId: childId,
      packageName: packageName,
      appName: appName,
      dailyLimitMs: limitMinutes * 60000,
    );
    _ref.invalidate(restrictionsProvider(childId));
  }

  Future<void> removeLimit({
    required String childId,
    required String packageName,
  }) async {
    await _repo.remove(childId: childId, packageName: packageName);
    _ref.invalidate(restrictionsProvider(childId));
  }
}

final appRestrictionRepositoryProvider =
    Provider<_AppLimitFacade>(_AppLimitFacade.new);
