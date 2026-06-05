// ─────────────────────────────────────────────────────────────────────
// app_usage_providers — Backend (Sprint 4.4.24)
// ─────────────────────────────────────────────────────────────────────
//
// Backend `0.5.1` LIVE — per-app limit endpoint mavjud. Stub olib
// tashlandi, real Backend repository ulandi.

import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun bugungi foydalanish — Backend fetch + 30 sek polling.
///
/// Backend hozir `app_usage:updated` WS event emit qilmaydi —
/// vaqtinchalik polling bilan ushlaymiz. Ekran ochiq paytda har 30 sek
/// yangi usage Backend'dan keladi (Child sync interval o'zgargach
/// foydalanuvchi 30 sek ichida ko'radi).
final todayUsageProvider =
    StreamProvider.family<AppUsageDay?, String>((ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield null;
    return;
  }
  final repo = ref.watch(backendAppUsageRepositoryProvider);

  // Birinchi fetch
  yield await repo.getTodayUsage(childId);

  // Polling — har 30 sek, faqat ekran ochiq ekan (provider hayot)
  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 30), (i) => i)) {
    yield await repo.getTodayUsage(childId);
  }
});

/// Bola qurilmasidagi o'rnatilgan ilovalar — Backend fetch + 5 daq polling.
final installedAppsProvider =
    StreamProvider.family<List<AppUsageEntry>, String>(
        (ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield const <AppUsageEntry>[];
    return;
  }
  final repo = ref.watch(backendAppUsageRepositoryProvider);
  yield await repo.getInstalledApps(childId: childId);

  // 60 sekundda bir refresh — yangi pair qilingan qurilmada nomlar/ikonalar
  // tezroq kelishi uchun (avval 5 daqiqa edi, ekran ochilganda kech edi).
  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 60), (i) => i)) {
    yield await repo.getInstalledApps(childId: childId);
  }
});

/// Oxirgi 7 kun foydalanish — Backend endpoint hozircha yo'q.
final last7DaysUsageProvider =
    StreamProvider.family<List<AppUsageDay>, String>((ref, childId) {
  return Stream.value(const <AppUsageDay>[]);
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
    Provider<_AppLimitFacade>((ref) => _AppLimitFacade(ref));
