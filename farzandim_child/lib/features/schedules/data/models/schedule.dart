// ─────────────────────────────────────────────────────────────────────
// Schedule — bola jadval modeli (faqat o'qish)
// ─────────────────────────────────────────────────────────────────────
//
// Firestore: users/{parentUid}/children/{childId}/schedules/{id}.
// Parent App yozadi, Child App o'qiydi — `toFirestore` shu sabab
// kerak emas.

import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleType { school, sport, sleep, meal, custom }

enum Weekday {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

extension ScheduleTypeX on ScheduleType {
  static ScheduleType fromName(String? name) {
    for (final t in ScheduleType.values) {
      if (t.name == name) return t;
    }
    return ScheduleType.custom;
  }
}

extension WeekdayX on Weekday {
  static Weekday fromName(String? name) {
    for (final w in Weekday.values) {
      if (w.name == name) return w;
    }
    return Weekday.monday;
  }
}

class Schedule {
  final String id;
  final String title;
  final ScheduleType type;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<Weekday> weekdays;
  final bool isActive;

  const Schedule({
    required this.id,
    required this.title,
    required this.type,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.weekdays,
    required this.isActive,
  });

  /// Backend REST `Routine` JSON'idan parse (Sprint 4.4.9 Day 3).
  ///
  /// Backend kontract:
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "title": "Maktab",
  ///   "type": "SLEEP|SCHOOL|HOMEWORK|SPORT|OTHER",
  ///   "startHour": 8, "startMinute": 0,
  ///   "endHour": 14, "endMinute": 0,
  ///   "weekdays": [1,2,3,4,5],  // ISO 8601
  ///   "isActive": true
  /// }
  /// ```
  ///
  /// Mapping: Backend uppercase type → Frontend lowercase enum.
  /// `weekdays` ISO int[] → Weekday enum list.
  factory Schedule.fromBackendJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'OTHER').toUpperCase();
    final type = _backendTypeToFrontend(typeStr);

    final rawWeekdays = (json['weekdays'] as List?) ?? const [];
    final weekdays = rawWeekdays
        .map((d) => _weekdayFromIso((d as num).toInt()))
        .toList(growable: false);

    return Schedule(
      id: json['id'] as String? ?? '',
      title: (json['title'] as String?) ?? '',
      type: type,
      startHour: (json['startHour'] as num?)?.toInt() ?? 0,
      startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (json['endHour'] as num?)?.toInt() ?? 0,
      endMinute: (json['endMinute'] as num?)?.toInt() ?? 0,
      weekdays: weekdays,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static ScheduleType _backendTypeToFrontend(String backendType) {
    switch (backendType) {
      case 'SLEEP':
        return ScheduleType.sleep;
      case 'SCHOOL':
        return ScheduleType.school;
      case 'SPORT':
        return ScheduleType.sport;
      case 'HOMEWORK':
      case 'OTHER':
      default:
        return ScheduleType.custom;
    }
  }

  static Weekday _weekdayFromIso(int iso) {
    if (iso < 1 || iso > 7) return Weekday.monday;
    return Weekday.values[iso - 1];
  }

  factory Schedule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    final rawWeekdays =
        (data['weekdays'] as List?)?.cast<dynamic>() ?? const [];
    final weekdays = rawWeekdays
        .map((e) => WeekdayX.fromName(e?.toString()))
        .toList(growable: false);

    return Schedule(
      id: doc.id,
      title: data['title'] as String? ?? '',
      type: ScheduleTypeX.fromName(data['type'] as String?),
      startHour: (data['startHour'] as num?)?.toInt() ?? 0,
      startMinute: (data['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (data['endHour'] as num?)?.toInt() ?? 0,
      endMinute: (data['endMinute'] as num?)?.toInt() ?? 0,
      weekdays: weekdays,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  String get startTimeFormatted => _format(startHour, startMinute);
  String get endTimeFormatted => _format(endHour, endMinute);
  String get timeRangeFormatted =>
      '$startTimeFormatted – $endTimeFormatted';

  static String _format(int h, int m) {
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
