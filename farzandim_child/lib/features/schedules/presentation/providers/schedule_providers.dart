// ─────────────────────────────────────────────────────────────────────
// schedule_providers — Backend Routines (Sprint 4.4.9 Day 3)
// ─────────────────────────────────────────────────────────────────────
//
// Eski Firestore listener'lar olib tashlandi. Backend `/today` endpoint
// optimized data qaytaradi (today + current + next + serverTime).
//
// `activeSchedulesProvider`  — Backend `/routines` (barcha aktiv)
// `todaySchedulesProvider`   — Backend `/today` `today[]`
// `currentScheduleProvider`  — Backend `/today` `current`
// `nextScheduleProvider`     — Backend `/today` `next`

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backend `GET /today` ma'lumotlari (today + current + next).
final todayRoutinesProvider =
    FutureProvider<TodayRoutines?>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return null;
  final repo = ref.watch(backendRoutineRepositoryProvider);
  return repo.getToday(childId);
});

/// Barcha aktiv rejalar (full list — schedule list ekrani uchun).
final activeSchedulesProvider =
    FutureProvider<List<Schedule>>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return const [];
  final repo = ref.watch(backendRoutineRepositoryProvider);
  final all = await repo.getRoutines(childId);
  // `today` providerlar uchun ham yaroqli — faqat aktiv.
  return all.where((s) => s.isActive).toList();
});

/// Bugungi rejalar — Backend `/today` `today[]`.
final todaySchedulesProvider = Provider<List<Schedule>>((ref) {
  final today = ref.watch(todayRoutinesProvider).valueOrNull;
  return today?.today ?? const <Schedule>[];
});

/// Hozir aktiv reja — Backend `/today` `current`.
final currentScheduleProvider = Provider<Schedule?>((ref) {
  return ref.watch(todayRoutinesProvider).valueOrNull?.current;
});

/// Keyingi reja — Backend `/today` `next`.
final nextScheduleProvider = Provider<Schedule?>((ref) {
  return ref.watch(todayRoutinesProvider).valueOrNull?.next;
});
