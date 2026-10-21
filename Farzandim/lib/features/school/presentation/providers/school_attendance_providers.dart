// ─────────────────────────────────────────────────────────────────────
// school_attendance_providers — o'quvchining oylik va bugungi davomati
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona uchun alohida "bugun" endpoint'i yo'q: bugungi holat joriy oy
// javobidan `tashkentTodayStr()` bilan olinadi. Oy kaliti har doim aniq
// "YYYY-MM" (null emas) — dashboard kartasi, maktab sahifasi va davomat
// ekrani bitta keshni bo'lishadi. WS event yo'q: push, resume va
// pull-to-refresh `invalidateSchoolData` orqali yangilaydi.

import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Oylik davomat kaliti: o'quvchi + oy ("YYYY-MM").
typedef MonthAttendanceArgs = ({String studentId, String month});

/// Ekranlar orasida tez o'tishda (dashboard ↔ maktab) qayta yuklanmasin.
const Duration _attendanceCacheTtl = Duration(minutes: 2);

/// Joriy Toshkent oyi, "YYYY-MM".
String currentSchoolMonth() => tashkentTodayStr().substring(0, 7);

/// O'quvchining bir oylik davomati (kalendar, jami, kelish foizi).
final monthAttendanceProvider = FutureProvider.autoDispose
    .family<MonthAttendance, MonthAttendanceArgs>((ref, args) async {
      // Hisobdan chiqilganda kesh tashlanadi — boshqa hisobga o'tmaydi.
      final signedIn = ref.watch(schoolSignedInProvider);
      if (signedIn == null) return untilSignInKnown();
      if (!signedIn) {
        throw const SchoolFailure(SchoolFailureKind.sessionExpired);
      }
      final repo = ref.watch(schoolRepositoryProvider);
      keepAliveFor(ref, _attendanceCacheTtl);
      return repo.fetchAttendance(studentId: args.studentId, month: args.month);
    });

/// O'quvchining BUGUNGI kuni (joriy oy javobidan). Bugun oyda topilmasa
/// (qurilma soati noto'g'ri) — `null`.
final todayAttendanceProvider = Provider.autoDispose
    .family<AsyncValue<AttendanceDay?>, String>((ref, studentId) {
      final today = tashkentTodayStr();
      final month = ref.watch(
        monthAttendanceProvider((
          studentId: studentId,
          month: today.substring(0, 7),
        )),
      );
      return month.whenData((attendance) => attendance.dayOf(today));
    });
