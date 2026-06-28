// Ilova foydalanish va cheklov ma'lumotlari uchun provayderlar.

import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun bugungi foydalanish — backend fetch + 30 sek polling.
///
/// Backend hozircha `app_usage:updated` WS event yubormaydi, shuning
/// uchun polling. `autoDispose` + 2 daqiqa keep-alive: ekran yopilgach
/// polling to'xtaydi, tez qaytishda esa loading "flash" bo'lmaydi.
final todayUsageProvider = StreamProvider.autoDispose
    .family<AppUsageDay?, String>((ref, childId) async* {
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
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

/// Bola qurilmasidagi o'rnatilgan ilovalar — backend fetch + 60s polling
/// (yangi pair qilingan qurilmada nomlar/ikonalar tez kelishi uchun).
/// `autoDispose` + 2 daqiqa keep-alive (yuqoridagi kabi).
final installedAppsProvider = StreamProvider.autoDispose
    .family<List<AppUsageEntry>, String>((ref, childId) async* {
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
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
        // Keshdagi ro'yxat darhol beriladi — ekran spinner'da turmaydi.
        readCache: () async {
          final cached = await repo.getCachedInstalledApps(childId);
          return (cached != null && cached.isNotEmpty) ? cached : null;
        },
      );
    });

/// Bola uchun cheklovlar — backend `/app-limits` orqali.
final restrictionsProvider =
    StreamProvider.family<List<AppRestriction>, String>((ref, childId) async* {
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
      if (!isAuthed) {
        yield const <AppRestriction>[];
        return;
      }
      final repo = ref.watch(backendAppLimitRepositoryProvider);
      yield await repo.getRestrictions(childId);
    });

/// UI semantikasini backend'ga moslaydigan facade: blok = dailyLimitMs 0,
/// limit X daqiqa = X * 60000, olib tashlash = DELETE.
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

final appRestrictionRepositoryProvider = Provider<_AppLimitFacade>(
  _AppLimitFacade.new,
);
