// Maktab bo'limi (v5) yangi ma'lumotlari: bolaga e'lonlar, davomat tarixi,
// dars jadvali. Kontrakt: docs/MAKTAB-BOLA-API.md (backend).

import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:flutter/foundation.dart';

@immutable
class SchoolNotice {
  const SchoolNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.important,
    required this.sentAt,
    required this.authorName,
    required this.authorRole,
    required this.forClass,
    required this.read,
    this.className,
  });

  static SchoolNotice? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['id']);
    final sentAt = jsonInstant(json['sentAt']);
    if (id == null || sentAt == null) return null;
    final author = json['author'];
    return SchoolNotice(
      id: id,
      title: jsonText(json['title']),
      body: jsonText(json['body']),
      important: json['priority'] == 'IMPORTANT',
      sentAt: sentAt,
      authorName: author is Map ? jsonText(author['name']) : '',
      authorRole: author is Map ? jsonText(author['role']) : '',
      forClass: json['audienceLabel'] == 'CLASS',
      className: jsonString(json['className']),
      read: json['read'] == true,
    );
  }

  final String id;
  final String title;
  final String body;
  final bool important;
  final DateTime sentAt;
  final String authorName;

  /// Server roli: DIRECTOR / ADMIN / HOMEROOM / TEACHER / PSYCHOLOGIST / DUTY.
  final String authorRole;
  final bool forClass;
  final String? className;
  final bool read;

  SchoolNotice markRead() => SchoolNotice(
    id: id,
    title: title,
    body: body,
    important: important,
    sentAt: sentAt,
    authorName: authorName,
    authorRole: authorRole,
    forClass: forClass,
    className: className,
    read: true,
  );
}

@immutable
class SchoolNoticePage {
  const SchoolNoticePage({required this.items, required this.unreadCount});

  static const empty = SchoolNoticePage(items: [], unreadCount: 0);

  final List<SchoolNotice> items;
  final int unreadCount;
}

/// Kunlik davomat holati (bola uchun). `unknown` — skanerlanmagan kun:
/// «Aniqlanmagan», «kelmagan» degani emas.
enum DayStatus { present, late, absent, excused, leftEarly, unknown }

DayStatus dayStatusFromWire(Object? value) => switch (value) {
  'PRESENT' => DayStatus.present,
  'LATE' => DayStatus.late,
  'ABSENT' => DayStatus.absent,
  'EXCUSED' => DayStatus.excused,
  'LEFT_EARLY' => DayStatus.leftEarly,
  _ => DayStatus.unknown,
};

@immutable
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.status,
    required this.confirmed,
    this.inAt,
    this.outAt,
    this.kioskIn,
    this.kioskOut,
  });

  static AttendanceDay? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final date = jsonDay(json['date']);
    if (date == null) return null;
    final kiosk = json['kiosk'];
    return AttendanceDay(
      date: date,
      status: dayStatusFromWire(json['status']),
      confirmed: json['confirmed'] == true,
      inAt: jsonClock(json['inAt']),
      outAt: jsonClock(json['outAt']),
      kioskIn: kiosk is Map ? jsonClock(kiosk['inAt']) : null,
      kioskOut: kiosk is Map ? jsonClock(kiosk['outAt']) : null,
    );
  }

  final DateTime date;
  final DayStatus status;

  /// Maktab xodimi belgilagan yoki tuzatgan.
  final bool confirmed;
  final String? inAt;
  final String? outAt;
  final String? kioskIn;
  final String? kioskOut;
}

@immutable
class AttendanceMonth {
  const AttendanceMonth({required this.month, required this.days});

  /// Oyning birinchi kuni.
  final DateTime month;
  final List<AttendanceDay> days;

  AttendanceDay? dayOf(DateTime date) {
    for (final d in days) {
      if (d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day) {
        return d;
      }
    }
    return null;
  }
}

@immutable
class TimetableLesson {
  const TimetableLesson({
    required this.periodNo,
    required this.start,
    required this.end,
    required this.subject,
    this.room,
    this.teacherName,
  });

  static TimetableLesson? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final no = jsonInt(json['periodNo']);
    final start = jsonClock(json['start']);
    final end = jsonClock(json['end']);
    final subject = jsonNonEmpty(json['subject']);
    if (no == null || start == null || end == null || subject == null) {
      return null;
    }
    return TimetableLesson(
      periodNo: no,
      start: start,
      end: end,
      subject: subject,
      room: jsonString(json['room']),
      teacherName: jsonString(json['teacherName']),
    );
  }

  final int periodNo;

  /// "HH:MM".
  final String start;
  final String end;

  /// Fan kaliti (`math`) yoki erkin nom («Jismoniy tarbiya»).
  final String subject;
  final String? room;
  final String? teacherName;
}

enum DayOffReason { weekend, holiday }

@immutable
class TimetableDay {
  const TimetableDay({
    required this.date,
    required this.weekday,
    required this.published,
    required this.lessons,
    this.className,
    this.shiftName,
    this.dayOff,
    this.holidayName,
  });

  static TimetableDay? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final date = jsonDay(json['date']);
    if (date == null) return null;
    final shift = json['shift'];
    final off = json['dayOff'];
    final lessons = json['lessons'];
    return TimetableDay(
      date: date,
      weekday: jsonInt(json['weekday']) ?? date.weekday,
      className: jsonString(json['className']),
      shiftName: shift is Map ? jsonString(shift['name']) : null,
      published: json['published'] == true,
      dayOff: off is Map
          ? (off['reason'] == 'HOLIDAY'
                ? DayOffReason.holiday
                : DayOffReason.weekend)
          : null,
      holidayName: off is Map ? jsonString(off['name']) : null,
      lessons: lessons is List
          ? jsonList(lessons, TimetableLesson.tryFromJson)
          : const [],
    );
  }

  final DateTime date;
  final int weekday;
  final String? className;
  final String? shiftName;
  final bool published;
  final DayOffReason? dayOff;
  final String? holidayName;
  final List<TimetableLesson> lessons;
}

/// "HH:MM" → shu kundagi vaqt.
DateTime clockOn(DateTime day, String clock) {
  final parts = clock.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.tryParse(parts[0]) ?? 0,
    int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
  );
}

/// Hozirgi va keyingi dars (bugungi kun uchun).
({TimetableLesson? now, TimetableLesson? next}) currentLessons(
  TimetableDay day,
  DateTime now,
) {
  TimetableLesson? current;
  TimetableLesson? next;
  for (final lesson in day.lessons) {
    final start = clockOn(day.date, lesson.start);
    final end = clockOn(day.date, lesson.end);
    if (!now.isBefore(start) && now.isBefore(end)) current = lesson;
    if (now.isBefore(start) && next == null) next = lesson;
  }
  return (now: current, next: next);
}
