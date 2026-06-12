// ─────────────────────────────────────────────────────────────────────
// app_usage_providers — Backend (Sprint 4.4.24)
// ─────────────────────────────────────────────────────────────────────
//
// Backend `0.5.1` LIVE — per-app limit endpoint mavjud. Stub olib
// tashlandi, real Backend repository ulandi.

import 'dart:async';

import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/core/utils/poll_backoff.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Polling provayder uchun qisqa keep-alive (P0-1).
///
/// `autoDispose` watcher ketishi bilan provider'ni darhol o'ldiradi —
/// foydalanuvchi tez orqaga qaytsa loading "flash" bo'lardi. 2 daqiqalik
/// keep-alive: tez qaytishda kesh turadi, uzoq ketilsa polling BUTUNLAY
/// to'xtaydi (avval `autoDispose`siz ekran bir marta ochilgach polling
/// ILOVA UMRI DAVOMIDA davom etardi — 100k user'da minglab keraksiz RPS).
void keepAliveFor(Ref<dynamic> ref, Duration duration) {
  final link = ref.keepAlive();
  final timer = Timer(duration, link.close);
  ref.onDispose(timer.cancel);
}

/// Bola uchun bugungi foydalanish — Backend fetch + 30 sek polling.
///
/// Backend hozir `app_usage:updated` WS event emit qilmaydi —
/// vaqtinchalik polling bilan ushlaymiz. `autoDispose` + lifecycle skip:
/// ekran yopilgach (2 daq keshdan keyin) va ilova fonda bo'lsa polling
/// TO'XTAYDI. Poll xatosi yutiladi — oxirgi qiymat saqlanadi.
final todayUsageProvider = StreamProvider.autoDispose
    .family<AppUsageDay?, String>((ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield null;
    return;
  }
  keepAliveFor(ref, const Duration(minutes: 2));
  // Zombi-guard: bekor qilingan generator faqat keyingi yield'da to'xtaydi —
  // `continue`/catch yo'llarida yield yo'q, guard'siz yetim generator fonda/
  // xato davrida abadiy poll qilaverardi.
  var alive = true;
  ref.onDispose(() => alive = false);
  final repo = ref.watch(backendAppUsageRepositoryProvider);

  // Birinchi fetch
  yield await repo.getTodayUsage(childId);

  // Polling — har 30 sek, faqat provider hayot VA ilova ko'rinib turganda.
  final backoff = PollBackoff();
  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 30), (i) => i)) {
    if (!alive) return;
    if (!isAppResumed(ref)) continue;
    if (backoff.shouldSkipTick) continue;
    try {
      yield await repo.getTodayUsage(childId);
      backoff.onSuccess();
    } catch (_) {
      // tarmoq blip — backoff: ketma-ket xatolarda siyraklashadi
      backoff.onFailure();
    }
  }
});

/// Bola qurilmasidagi o'rnatilgan ilovalar — Backend fetch + 60s polling.
/// `autoDispose` + lifecycle skip (P0-1, yuqoridagi kabi).
final installedAppsProvider = StreamProvider.autoDispose
    .family<List<AppUsageEntry>, String>((ref, childId) async* {
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  if (!isAuthed) {
    yield const <AppUsageEntry>[];
    return;
  }
  keepAliveFor(ref, const Duration(minutes: 2));
  // Zombi-guard (todayUsage'dagi kabi).
  var alive = true;
  ref.onDispose(() => alive = false);
  final repo = ref.watch(backendAppUsageRepositoryProvider);

  // NET-07 (SWR): keshdagi ro'yxat DARHOL — ekran spinner'da turmaydi.
  final cachedApps = await repo.getCachedInstalledApps(childId);
  if (cachedApps != null && cachedApps.isNotEmpty) {
    yield cachedApps;
  }

  try {
    yield await repo.getInstalledApps(childId: childId);
  } catch (_) {
    // Kesh ko'rsatilgan bo'lsa saqlanadi (offline UX), bo'lmasa error.
    if (cachedApps == null || cachedApps.isEmpty) rethrow;
  }

  // 60 sekundda bir refresh — yangi pair qilingan qurilmada nomlar/ikonalar
  // tezroq kelishi uchun (avval 5 daqiqa edi, ekran ochilganda kech edi).
  final backoff = PollBackoff();
  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 60), (i) => i)) {
    if (!alive) return;
    if (!isAppResumed(ref)) continue;
    if (backoff.shouldSkipTick) continue;
    try {
      yield await repo.getInstalledApps(childId: childId);
      backoff.onSuccess();
    } catch (_) {
      // skip — backoff: ketma-ket xatolarda siyraklashadi
      backoff.onFailure();
    }
  }
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
