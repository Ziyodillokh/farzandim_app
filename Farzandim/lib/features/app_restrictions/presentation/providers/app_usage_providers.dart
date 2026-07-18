// Ilova foydalanish va cheklov ma'lumotlari uchun provayderlar.

import 'dart:async';

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_usage_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
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

/// Bola uchun haftalik qadamlar — REAL-TIME (WS `steps:updated`) + 30s poll
/// fallback. Dashboard "Kunlik qadamlar" + "Kunlik rivojlanish" kartalari.
///
/// Avval faqat 60s polling edi → bola yurgani ota-onaga ~1-2 daqiqada yetardi.
/// Endi bola qadamini backend socket orqali darhol yuboradi; bu yerda bugungi
/// kun payload'dan yamlanadi (refetch'siz, bir necha soniya). Location
/// provider bilan bir xil pattern: WS + reconnect resync + resume + poll
/// fallback (socket uzuq bo'lsa).
final weeklyStepsProvider = StreamProvider.autoDispose
    .family<WeeklySteps?, String>((ref, childId) async* {
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
      if (!isAuthed) {
        yield null;
        return;
      }
      keepAliveFor(ref, const Duration(minutes: 2));
      var alive = true;
      ref.onDispose(() => alive = false);

      final repo = ref.watch(backendAppUsageRepositoryProvider);
      final socket = ref.watch(socketClientProvider);

      final controller = StreamController<WeeklySteps?>();
      WeeklySteps? last;
      void push(WeeklySteps? w) {
        if (!alive || controller.isClosed) return;
        last = w;
        controller.add(w);
      }

      Future<void> resync() async {
        try {
          push(await repo.getWeeklySteps(childId));
        } catch (_) {/* oxirgi qiymat qoladi, keyingi kanal qayta uradi */}
      }

      // WS `steps:updated` — bugungi kunni payload'dan darhol yamaymiz
      // (refetch'siz, real-time). Kun topilmasa yoki bazaviy qiymat yo'q
      // bo'lsa — REST resync.
      final wsSub = repo.stepsEvents(childId).listen((payload) {
        final base = last;
        final steps = (payload['steps'] as num?)?.toInt();
        final dateStr = payload['date'] as String?;
        final d = dateStr != null ? DateTime.tryParse(dateStr) : null;
        if (base == null || steps == null || d == null) {
          unawaited(resync());
          return;
        }
        var found = false;
        final newDays = base.days.map((day) {
          if (day.date.year == d.year &&
              day.date.month == d.month &&
              day.date.day == d.day) {
            found = true;
            return DailySteps(date: day.date, steps: steps);
          }
          return day;
        }).toList();
        if (!found) {
          unawaited(resync());
          return;
        }
        final total = newDays.fold<int>(0, (s, x) => s + x.steps);
        push(WeeklySteps(days: newDays, weekTotal: total));
      });

      // Socket qayta ulandi — uzilish davridagi o'zgarishlarni tiklaymiz.
      final stateSub = socket.stateStream.listen((s) {
        if (s == SocketConnectionState.connected) unawaited(resync());
      });
      // Fondan qaytganda ham yangilaymiz.
      final lifecycleSub = ref.listen<AppLifecycleState>(
        appLifecycleProvider,
        (prev, next) {
          if (next == AppLifecycleState.resumed &&
              prev != AppLifecycleState.resumed) {
            unawaited(resync());
          }
        },
      );
      // Socket uzuq paytda 30s polling fallback.
      final pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!alive || !isAppResumed(ref)) return;
        if (socket.state == SocketConnectionState.connected) return;
        unawaited(resync());
      });

      ref.onDispose(() {
        pollTimer.cancel();
        unawaited(wsSub.cancel());
        unawaited(stateSub.cancel());
        lifecycleSub.close();
        unawaited(controller.close());
      });

      // Boshlang'ich fetch.
      await resync();

      yield* controller.stream;
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
