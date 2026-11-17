// ─────────────────────────────────────────────────────────────────────
// school_format — maktab ekranlaridagi sana va vaqt ko'rinishi
// ─────────────────────────────────────────────────────────────────────
//
// Ilovaning boshqa joylari kabi intl'siz: "20.10.2026", "14:05".
// Kun-kalitlari ("YYYY-MM-DD") Toshkent kuni — vaqt mintaqasiz
// formatlanadi; server vaqtlari (`DateTime`) allaqachon mahalliy.
// Oy va hafta kuni nomlari mavjud tarjimalardan olinadi
// (`leaderboard.months.*`, `dashboard.chart.weekdays.*`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';

final RegExp _dayKey = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

String _two(int value) => value.toString().padLeft(2, '0');

/// "2026-10-20" → "20.10.2026"; boshqa shakl o'zgarishsiz qaytadi.
String formatSchoolDay(String dayKey) {
  final match = _dayKey.firstMatch(dayKey);
  if (match == null) return dayKey;
  return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
}

/// "2026-10-20" → "20.10" (joriy oy ro'yxatlari uchun).
String formatSchoolDayShort(String dayKey) {
  final match = _dayKey.firstMatch(dayKey);
  if (match == null) return dayKey;
  return '${match.group(3)}.${match.group(2)}';
}

/// Mahalliy sana → "20.10.2026".
String formatSchoolDate(DateTime date) =>
    '${_two(date.day)}.${_two(date.month)}.${date.year}';

/// Mahalliy vaqt → "14:05".
String formatSchoolTime(DateTime date) =>
    '${_two(date.hour)}:${_two(date.minute)}';

/// Soat + daqiqa → "HH:MM" (24 soat, backend formati).
String formatHhMm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

/// Mahalliy vaqt belgisi: bugun → "Bugun, 14:05", aks holda
/// "20.10.2026, 14:05". [now] — testlar uchun.
String schoolStampLabel(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final time = formatSchoolTime(at);
  final sameDay =
      at.year == today.year && at.month == today.month && at.day == today.day;
  return sameDay
      ? 'school.todayAt'.tr(namedArgs: {'time': time})
      : '${formatSchoolDate(at)}, $time';
}

/// Kun-kalit + "HH:MM": bugun → "Bugun, 13:30", aks holda
/// "20.10.2026, 13:30".
String schoolDayTimeLabel(
  String dayKey,
  String time, {
  required String today,
}) => dayKey == today
    ? 'school.todayAt'.tr(namedArgs: {'time': time})
    : '${formatSchoolDay(dayKey)}, $time';

/// "2026-10" → "Oktyabr 2026" (rus tilida ham bosh harf bilan).
String schoolMonthTitle(String month) {
  final parsed = parseSchoolMonth(month);
  if (parsed == null) return month;
  final name = 'leaderboard.months.${parsed.month}'.tr();
  final title = name.isEmpty
      ? name
      : '${name[0].toUpperCase()}${name.substring(1)}';
  return '$title ${parsed.year}';
}

/// Hafta kuni qisqa nomi ("Du"); [weekday] — `DateTime.weekday` (1–7).
String schoolWeekdayShort(int weekday) =>
    'dashboard.chart.weekdays.$weekday'.tr();
