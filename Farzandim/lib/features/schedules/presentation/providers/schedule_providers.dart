// ─────────────────────────────────────────────────────────────────────
// schedule_providers — Backend Routines (Sprint 4.4.4)
// ─────────────────────────────────────────────────────────────────────
//
// **Eslatma:** Frontend `Schedule` ≡ Backend `Routine` (kun rejasi).
// Backend `Schedule` (BLOCK/ALLOW app cheklash) — alohida feature,
// hozircha Frontend UI'da yo'q.
//
// Eski: Firestore stream + Firebase Auth.
// Yangi: Backend REST + WS `routine:created/updated/deleted` real-time.

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun barcha routine'lar (kun rejasi) — Backend fetch + WS refresh.
final schedulesProvider = StreamProvider.family<List<Schedule>, String>((
  ref,
  childId,
) async* {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) {
    yield const <Schedule>[];
    return;
  }

  final repo = ref.watch(backendRoutineRepositoryProvider);
  yield await repo.getRoutines(childId);

  final controller = StreamController<List<Schedule>>();
  Future<void> refresh() async {
    if (controller.isClosed) return;
    final list = await repo.getRoutines(childId);
    if (!controller.isClosed) controller.add(list);
  }

  final createdSub = repo.createdStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });
  final updatedSub = repo.updatedStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });
  final deletedSub = repo.deletedStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });

  ref.onDispose(() {
    createdSub.cancel();
    updatedSub.cancel();
    deletedSub.cancel();
    controller.close();
  });

  yield* controller.stream;
});

/// Routine action'lari notifier'i (Backend Dio).
class ScheduleActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ScheduleActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  BackendRoutineRepository get _repo =>
      _ref.read(backendRoutineRepositoryProvider);

  /// Yangi routine qo'shish.
  Future<Result<void>> addSchedule({
    required String childId,
    required String title,
    required ScheduleType type,
    required List<Weekday> weekdays,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int reminderMinutes, // Backend'da yo'q — saqlanmaydi
    bool isActive = true,
    List<String> blockedApps = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final routine = Schedule(
        id: '',
        parentUid: '',
        childId: childId,
        title: title,
        type: type,
        weekdays: weekdays,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        reminderMinutes: reminderMinutes,
        isActive: isActive,
        blockedApps: blockedApps,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repo.createRoutine(childId: childId, routine: routine);
      _ref.invalidate(schedulesProvider(childId));
      state = const AsyncValue.data(null);
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// Mavjud routine'ni yangilash. `current` — existing Schedule
  /// (`geoZoneByIdProvider` pattern bilan).
  Future<Result<void>> updateSchedule({
    required String childId,
    required String scheduleId,
    required Schedule current,
    String? title,
    ScheduleType? type,
    List<Weekday>? weekdays,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? reminderMinutes,
    bool? isActive,
    List<String>? blockedApps,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = current.copyWith(
        title: title,
        type: type,
        weekdays: weekdays,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        reminderMinutes: reminderMinutes,
        isActive: isActive,
        blockedApps: blockedApps,
        updatedAt: DateTime.now(),
      );
      await _repo.updateRoutine(routineId: scheduleId, routine: updated);
      _ref.invalidate(schedulesProvider(childId));
      state = const AsyncValue.data(null);
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// `isActive` toggle qisqa wrapper.
  Future<Result<void>> toggleActive({
    required String childId,
    required String scheduleId,
    required Schedule current,
    required bool isActive,
  }) {
    return updateSchedule(
      childId: childId,
      scheduleId: scheduleId,
      current: current,
      isActive: isActive,
    );
  }

  /// Routine'ni o'chirish.
  Future<Result<void>> deleteSchedule({
    required String childId,
    required String scheduleId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ok = await _repo.deleteRoutine(scheduleId);
      if (ok) _ref.invalidate(schedulesProvider(childId));
      state = const AsyncValue.data(null);
      return ok
          ? const Result<void>.success()
          : const Result<void>.failure('Amal bajarilmadi');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }
}

final scheduleActionsProvider =
    StateNotifierProvider<ScheduleActionsNotifier, AsyncValue<void>>(
      ScheduleActionsNotifier.new,
    );
