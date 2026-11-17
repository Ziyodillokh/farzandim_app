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
// `todayScheduleListProvider` — ekrandagi ro'yxat: `/today` + "Maktab rejimi"
//
// Server "Maktab rejimi" oynalarini faqat bugun uchun yuboradi (bayram,
// istisno, favqulodda holat) — "Mening jadvalim" ochilganda va kun
// almashganda bu providerlar qayta yuklanadi (`refreshTodaySchedules`).

import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backend `GET /today` ma'lumotlari (today + current + next).
final todayRoutinesProvider = FutureProvider<TodayRoutines?>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return null;
  final repo = ref.watch(backendRoutineRepositoryProvider);
  return repo.getToday(childId);
});

/// Barcha aktiv rejalar (full list — schedule list ekrani uchun).
final activeSchedulesProvider = FutureProvider<List<Schedule>>((ref) async {
  final pairing = ref.watch(pairingStateProvider);
  final childId = pairing.childId;
  if (childId == null) return const [];
  final repo = ref.watch(backendRoutineRepositoryProvider);
  // Repo tarmoq xatosida `null` qaytaradi (fail-closed enforcement uchun).
  // Bu yer faqat KO'RSATISH — bo'sh ro'yxat xavfsiz (blok emas).
  final all = await repo.getRoutines(childId) ?? const <Schedule>[];
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

/// Ekrandagi bugungi ro'yxat: `/today` jadvallari va maktab "Maktab rejimi"
/// (server uni faqat `/routines`da, bugungi kun uchun yuboradi).
final todayScheduleListProvider = Provider<List<Schedule>>((ref) {
  final all = ref.watch(activeSchedulesProvider).valueOrNull ?? const [];
  return withSchoolModeSchedules(
    ref.watch(todaySchedulesProvider),
    all,
    tashkentNow().weekday,
  );
});

/// [today]ga [all] ichidagi bugungi (`isoWeekday`, 1 = dushanba) "Maktab
/// rejimi" jadvallari qo'shiladi — boshlanish vaqti bo'yicha. Bunday jadval
/// bo'lmasa [today] o'zgarmay qaytadi.
List<Schedule> withSchoolModeSchedules(
  List<Schedule> today,
  List<Schedule> all,
  int isoWeekday,
) {
  if (isoWeekday < 1 || isoWeekday > Weekday.values.length) return today;
  final weekday = Weekday.values[isoWeekday - 1];
  final shown = {for (final s in today) s.id};
  final school = [
    for (final s in all)
      if (s.isSchoolMode &&
          s.weekdays.contains(weekday) &&
          !shown.contains(s.id))
        s,
  ];
  if (school.isEmpty) return today;
  int startOf(Schedule s) => s.startHour * 60 + s.startMinute;
  return List.unmodifiable(
    [...today, ...school]..sort((a, b) => startOf(a).compareTo(startOf(b))),
  );
}

/// Jadval [now] (devor soati) paytida davom etyaptimi — tun o'tadigan
/// oyna (22:00–07:00) ham hisobga olinadi.
bool isScheduleActiveAt(Schedule schedule, DateTime now) {
  final minute = _minuteOfDay(now);
  final start = _startMinute(schedule);
  final end = schedule.endHour * 60 + schedule.endMinute;
  if (start == end) return false;
  return start < end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
}

/// "Hozir" qatori: server `/today` `current`i, bo'lmasa [today] ro'yxatidagi
/// hozir davom etayotgan "Maktab rejimi" (u `/today`da yo'q).
Schedule? currentScheduleAt(
  List<Schedule> today,
  Schedule? serverCurrent,
  DateTime now,
) {
  if (serverCurrent != null) return serverCurrent;
  for (final s in today) {
    if (s.isSchoolMode && isScheduleActiveAt(s, now)) return s;
  }
  return null;
}

/// "Keyingi" qatori: server `next`i va [today]dagi hali boshlanmagan
/// "Maktab rejimi"dan eng oldin boshlanadigani.
Schedule? nextScheduleAt(
  List<Schedule> today,
  Schedule? serverNext,
  DateTime now,
) {
  final minute = _minuteOfDay(now);
  var next = serverNext;
  for (final s in today) {
    if (!s.isSchoolMode || _startMinute(s) <= minute) continue;
    if (next == null || _startMinute(s) < _startMinute(next)) next = s;
  }
  return next;
}

int _minuteOfDay(DateTime time) => time.hour * 60 + time.minute;

int _startMinute(Schedule s) => s.startHour * 60 + s.startMinute;

/// Bugungi jadvallarni serverdan qayta so'rash: "Maktab rejimi" oynalari
/// kunga bog'liq va hafta kuni ro'yxat hisoblangan paytda olinadi.
void refreshTodaySchedules(WidgetRef ref) {
  ref
    ..invalidate(todayRoutinesProvider)
    ..invalidate(activeSchedulesProvider);
}
