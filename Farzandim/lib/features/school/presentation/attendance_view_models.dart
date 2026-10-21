// ─────────────────────────────────────────────────────────────────────
// attendance_view_models — davomat ekranining sof (widget'siz) mantig'i
// ─────────────────────────────────────────────────────────────────────
//
// Oy kalitlari ("YYYY-MM"), Dushanbadan boshlanadigan kalendar to'ri,
// kunlar ro'yxati va oy jami qatorlari. Sanalar Toshkent kun-kalitlari
// ("YYYY-MM-DD") — satr sifatida to'g'ri tartiblanadi. Unit testlar bilan
// tekshiriladi.

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter/foundation.dart';

/// "YYYY-MM", oy 01–12 (backend `monthSchema` bilan bir xil).
final RegExp _monthKey = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$');

String _two(int value) => value.toString().padLeft(2, '0');

/// "YYYY-MM" → yil va oy; buzuq yoki `null` → `null`.
({int year, int month})? parseSchoolMonth(String? value) {
  final match = value == null ? null : _monthKey.firstMatch(value);
  if (match == null) return null;
  return (year: int.parse(match.group(1)!), month: int.parse(match.group(2)!));
}

/// Yil + oy → "YYYY-MM".
String schoolMonthKey(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${_two(month)}';

/// [month]dan [delta] oy keyin (manfiy — oldin); buzuq kalit → `null`.
String? shiftSchoolMonth(String month, int delta) {
  final parsed = parseSchoolMonth(month);
  if (parsed == null) return null;
  final index = parsed.year * 12 + parsed.month - 1 + delta;
  if (index < 0) return null;
  return schoolMonthKey(index ~/ 12, index % 12 + 1);
}

/// Ko'rsatiladigan oy: so'ralgani to'g'ri va kelajakda bo'lmasa — o'zi;
/// aks holda [current] (joriy Toshkent oyi).
String resolveSchoolMonth(String? requested, {required String current}) {
  if (requested == null || parseSchoolMonth(requested) == null) {
    return current;
  }
  return requested.compareTo(current) > 0 ? current : requested;
}

/// Kalendarning bitta katagi (oy kuni).
@immutable
class AttendanceCalendarCell {
  const AttendanceCalendarCell({
    required this.day,
    required this.date,
    required this.status,
    required this.isToday,
    required this.isFuture,
  });

  /// Oy kuni, 1–31.
  final int day;

  /// "YYYY-MM-DD".
  final String date;
  final SchoolDayStatus status;
  final bool isToday;

  /// Bugundan keyingi kun — holati ko'rsatilmaydi.
  final bool isFuture;
}

/// Dushanbadan boshlanadigan oy to'ri; oy boshidagi bo'sh kataklar `null`.
/// Kunlar oy kalitidan quriladi (javobda kun yetishmasa ham to'r to'liq),
/// holat esa javobdagi kundan olinadi. Buzuq oy → bo'sh ro'yxat.
List<AttendanceCalendarCell?> attendanceCalendarCells(
  MonthAttendance attendance, {
  required String today,
}) {
  final parsed = parseSchoolMonth(attendance.month);
  if (parsed == null) return const [];
  final (:year, :month) = parsed;
  final leading = DateTime.utc(year, month).weekday - DateTime.monday;
  final length = DateTime.utc(year, month + 1, 0).day;
  final byDate = {for (final day in attendance.days) day.date: day};
  return List.unmodifiable(<AttendanceCalendarCell?>[
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= length; day++)
      _cell(
        day: day,
        date: '${schoolMonthKey(year, month)}-${_two(day)}',
        byDate: byDate,
        today: today,
      ),
  ]);
}

AttendanceCalendarCell _cell({
  required int day,
  required String date,
  required Map<String, AttendanceDay> byDate,
  required String today,
}) {
  final order = date.compareTo(today);
  return AttendanceCalendarCell(
    day: day,
    date: date,
    status: SchoolDayStatus.of(byDate[date]),
    isToday: order == 0,
    isFuture: order > 0,
  );
}

/// Ro'yxatdagi kunlar (yangisi oldin): bugungacha bo'lgan o'quv kunlari va
/// yozuvi bor har qanday kun (dam olish kunidagi belgi ham).
List<AttendanceDay> attendanceListDays(
  MonthAttendance attendance, {
  required String today,
}) {
  final days =
      attendance.days
          .where(
            (d) =>
                d.date.compareTo(today) <= 0 &&
                (d.schoolDay || d.record != null),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  return List.unmodifiable(days);
}

/// Kelish foizini ko'rsatish mumkinmi: kamida bitta belgilangan o'quv kuni
/// bor (aks holda "0%" chalg'itadi).
bool hasAttendanceRate(AttendanceSummary summary) =>
    summary.total - summary.pending > 0;

/// Oy jami qatorlari — faqat noldan kattalari, kalendar ranglari tartibida.
List<({SchoolDayStatus status, int count})> attendanceSummaryEntries(
  AttendanceSummary summary,
) {
  final all = [
    (status: SchoolDayStatus.present, count: summary.present),
    (status: SchoolDayStatus.late, count: summary.late),
    (status: SchoolDayStatus.absent, count: summary.absent),
    (status: SchoolDayStatus.leftEarly, count: summary.leftEarly),
    (status: SchoolDayStatus.excused, count: summary.excused),
    (status: SchoolDayStatus.pending, count: summary.pending),
  ];
  return List.unmodifiable(all.where((entry) => entry.count > 0));
}
