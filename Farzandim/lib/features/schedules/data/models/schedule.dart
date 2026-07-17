import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Jadval kategoriyasi — ikona, rang va default label aniqlaydi.
enum ScheduleType {
  /// Maktab darslari.
  school,

  /// Sport mashg'ulotlari.
  sport,

  /// Uyqu / dam olish.
  sleep,

  /// Ovqatlanish.
  meal,

  /// Boshqa (foydalanuvchi yozadi).
  custom,
}

/// `ScheduleType` uchun UI helper'lar (ikona, rang, label).
extension ScheduleTypeX on ScheduleType {
  /// Ikona — kartochka chap tomonidagi yumaloq circle ichida.
  IconData get icon {
    switch (this) {
      case ScheduleType.school:
        return SolarIconsBold.squareAcademicCap;
      case ScheduleType.sport:
        return SolarIconsBold.football;
      case ScheduleType.sleep:
        return SolarIconsBold.moonSleep;
      case ScheduleType.meal:
        return SolarIconsBold.chefHat;
      case ScheduleType.custom:
        return SolarIconsBold.calendarMark;
    }
  }

  /// Tematik rang — circle fon (15% alpha) va ikona uchun.
  Color get color {
    switch (this) {
      case ScheduleType.school:
        return const Color(0xFF60A5FA); // moviy
      case ScheduleType.sport:
        return const Color(0xFFFB923C); // to'q sariq
      case ScheduleType.sleep:
        return const Color(0xFF818CF8); // indigo
      case ScheduleType.meal:
        return const Color(0xFF4ADE80); // yashil
      case ScheduleType.custom:
        return const Color(0xFF9CA3AF); // kulrang
    }
  }

  /// O'zbekcha label — type chip va default title uchun.
  String get label {
    switch (this) {
      case ScheduleType.school:
        return 'schedules.type.school'.tr();
      case ScheduleType.sport:
        return 'schedules.type.sport'.tr();
      case ScheduleType.sleep:
        return 'schedules.type.sleep'.tr();
      case ScheduleType.meal:
        return 'schedules.type.meal'.tr();
      case ScheduleType.custom:
        return 'schedules.type.custom'.tr();
    }
  }
}

/// Hafta kuni — Du-Ya. ISO 8601 raqamlari ([WeekdayX.iso]) bilan
/// mos keladi (Du=1, Ya=7).
enum Weekday {
  /// Dushanba (ISO 1).
  monday,

  /// Seshanba (ISO 2).
  tuesday,

  /// Chorshanba (ISO 3).
  wednesday,

  /// Payshanba (ISO 4).
  thursday,

  /// Juma (ISO 5).
  friday,

  /// Shanba (ISO 6).
  saturday,

  /// Yakshanba (ISO 7).
  sunday,
}

/// `Weekday` uchun label va ISO raqam.
extension WeekdayX on Weekday {
  /// 2-harfli qisqa label — chip pickerda ko'rsatish uchun.
  String get label {
    switch (this) {
      case Weekday.monday:
        return 'schedules.weekdayShort.monday'.tr();
      case Weekday.tuesday:
        return 'schedules.weekdayShort.tuesday'.tr();
      case Weekday.wednesday:
        return 'schedules.weekdayShort.wednesday'.tr();
      case Weekday.thursday:
        return 'schedules.weekdayShort.thursday'.tr();
      case Weekday.friday:
        return 'schedules.weekdayShort.friday'.tr();
      case Weekday.saturday:
        return 'schedules.weekdayShort.saturday'.tr();
      case Weekday.sunday:
        return 'schedules.weekdayShort.sunday'.tr();
    }
  }

  /// To'liq nom — accessibility tooltip va detail ekran uchun.
  String get fullLabel {
    switch (this) {
      case Weekday.monday:
        return 'Dushanba';
      case Weekday.tuesday:
        return 'Seshanba';
      case Weekday.wednesday:
        return 'Chorshanba';
      case Weekday.thursday:
        return 'Payshanba';
      case Weekday.friday:
        return 'Juma';
      case Weekday.saturday:
        return 'Shanba';
      case Weekday.sunday:
        return 'Yakshanba';
    }
  }

  /// ISO 8601 weekday raqami (Du=1, Ya=7) — `DateTime.weekday` bilan
  /// solishtirish uchun.
  int get iso => index + 1;
}

/// ISO 8601 raqamidan `Weekday` qaytaradi (1..7). Noto'g'ri qiymatda
/// `Weekday.monday` qaytaradi.
Weekday weekdayFromIso(int iso) {
  if (iso < 1 || iso > 7) return Weekday.monday;
  return Weekday.values[iso - 1];
}

/// Bola jadvalining bitta yozuvi — hafta'da takrorlanadigan.
///
/// **Firestore:** `users/{parentUid}/children/{childId}/schedules/{id}`
/// subcollection. Per-child — har bola alohida jadvallari.
///
/// **Vaqt format:** `startHour`/`startMinute`/`endHour`/`endMinute` —
/// 4 ta int. Cloud Function reminder uchun shu formatdan foydalanadi
/// (TimeOfDay Firestore'ga to'g'ridan-to'g'ri yozilmaydi).
@immutable
class Schedule {
  /// `Schedule` konstruktor.
  const Schedule({
    required this.id,
    required this.parentUid,
    required this.childId,
    required this.title,
    required this.type,
    required this.weekdays,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.reminderMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.blockedApps = const [],
  });

  /// Backend REST `Routine` JSON'idan parse (Sprint 4.4.4).
  ///
  /// **Eslatma:** Frontend `Schedule` model semantik Backend `Routine`'ga
  /// teng (kun rejasi — SLEEP/SCHOOL/SPORT). Backend `Schedule` ≠ bu —
  /// u app cheklash (BLOCK/ALLOW), hozircha Frontend UI'da yo'q.
  ///
  /// Backend Routine kontract:
  /// ```json
  /// {
  ///   "id": "uuid", "childId": "uuid", "title": "...",
  ///   "type": "SLEEP|SCHOOL|HOMEWORK|SPORT|OTHER",
  ///   "startHour": 22, "startMinute": 0,
  ///   "endHour": 7, "endMinute": 0,
  ///   "weekdays": [1,2,3,4,5,6,7],
  ///   "isActive": true,
  ///   "createdAt": "...", "updatedAt": "..."
  /// }
  /// ```
  ///
  /// `parentUid` Backend'da yo'q — caller'dan keladi.
  /// `reminderMinutes` Backend'da yo'q — default 10 (saqlanmaydi).
  factory Schedule.fromBackendJson(
    Map<String, dynamic> json, {
    required String parentUid,
  }) {
    final typeStr = (json['type'] as String? ?? 'OTHER').toUpperCase();
    final type = _backendTypeToFrontend(typeStr);

    final weekdaysRaw = json['weekdays'] as List<dynamic>? ?? const [];
    final weekdays = weekdaysRaw
        .map((d) => weekdayFromIso(d as int))
        .toList(growable: false);

    final blockedRaw = json['blockedApps'] as List<dynamic>? ?? const [];
    final blockedApps = blockedRaw.map((e) => '$e').toList(growable: false);

    return Schedule(
      id: json['id'] as String? ?? '',
      parentUid: parentUid,
      childId: json['childId'] as String? ?? '',
      title: (json['title'] as String?) ?? '',
      type: type,
      weekdays: weekdays,
      startHour: (json['startHour'] as num?)?.toInt() ?? 0,
      startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (json['endHour'] as num?)?.toInt() ?? 0,
      endMinute: (json['endMinute'] as num?)?.toInt() ?? 0,
      reminderMinutes: 10, // Backend'da yo'q
      isActive: json['isActive'] as bool? ?? true,
      blockedApps: blockedApps,
      createdAt:
          _parseBackendIso(json['createdAt'] as String?) ?? DateTime.now(),
      updatedAt:
          _parseBackendIso(json['updatedAt'] as String?) ?? DateTime.now(),
    );
  }

  /// Backend `POST/PUT /api/routines` uchun payload.
  Map<String, dynamic> toBackendJson() {
    return {
      'title': title,
      'type': _frontendTypeToBackend(type),
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'weekdays': weekdays.map((w) => w.iso).toList(),
      'isActive': isActive,
      'blockedApps': blockedApps,
    };
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

  static String _frontendTypeToBackend(ScheduleType type) {
    switch (type) {
      case ScheduleType.sleep:
        return 'SLEEP';
      case ScheduleType.school:
        return 'SCHOOL';
      case ScheduleType.sport:
        return 'SPORT';
      case ScheduleType.meal:
      case ScheduleType.custom:
        return 'OTHER';
    }
  }

  static DateTime? _parseBackendIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Firestore document ID (write paytida bo'sh, server beradi).
  final String id;

  /// Ota-ona Firebase UID — query filter va auth qoidalari uchun.
  final String parentUid;

  /// Qaysi bola uchun jadval (per-child).
  final String childId;

  /// Yozuv sarlavhasi — foydalanuvchi yozadi yoki type label.
  final String title;

  /// Yozuv kategoriyasi (default `custom`).
  final ScheduleType type;

  /// Qaysi kunlarda takrorlanadi.
  final List<Weekday> weekdays;

  /// Boshlanish soati (0-23).
  final int startHour;

  /// Boshlanish daqiqasi (0-59).
  final int startMinute;

  /// Tugash soati (0-23).
  final int endHour;

  /// Tugash daqiqasi (0-59).
  final int endMinute;

  /// Reminder push vaqti — boshlanishidan necha daqiqa oldin
  /// (0/5/10/15/30). 0 — reminder yo'q.
  final int reminderMinutes;

  /// Yozuv yoqilganmi (false bo'lsa Cloud Function reminder yubormaydi).
  final bool isActive;

  /// "Ilova cheklovlar" — jadval oynasida (startTime..endTime, weekdays)
  /// bloklanadigan ilova paketlari. Bo'sh bo'lsa "Kiritilmagan".
  final List<String> blockedApps;

  /// Yaratilgan vaqt (server timestamp).
  final DateTime createdAt;

  /// Oxirgi yangilanish vaqti (server timestamp).
  final DateTime updatedAt;

  /// `TimeOfDay` boshlanish vaqti (UI TimePicker uchun).
  TimeOfDay get startTime => TimeOfDay(hour: startHour, minute: startMinute);

  /// `TimeOfDay` tugash vaqti (UI TimePicker uchun).
  TimeOfDay get endTime => TimeOfDay(hour: endHour, minute: endMinute);

  /// Boshlanish vaqti `HH:MM` formatda — list ekranida ko'rsatish uchun.
  String get startTimeFormatted =>
      '${startHour.toString().padLeft(2, '0')}:'
      '${startMinute.toString().padLeft(2, '0')}';

  /// Tugash vaqti `HH:MM` formatda.
  String get endTimeFormatted =>
      '${endHour.toString().padLeft(2, '0')}:'
      '${endMinute.toString().padLeft(2, '0')}';

  /// Vaqt oraliqi `HH:MM - HH:MM` formatda.
  String get timeRangeFormatted => '$startTimeFormatted - $endTimeFormatted';

  /// Boshlanish vaqti minutlarda (sortlash uchun).
  int get startMinutes => startHour * 60 + startMinute;

  /// Hafta kunlari foydalanuvchi-friendly format:
  /// - 7 ta — "Har kuni"
  /// - 5 ta (Du-Ju) — "Hafta ichi"
  /// - 2 ta (Sh+Ya) — "Hafta oxiri"
  /// - aks holda — "Du, Pa, Ju" (qisqa label'lar)
  String get weekdaysFormatted {
    final set = weekdays.toSet();
    if (set.length == 7) return 'schedules.edit.shortcutAll'.tr();
    const weekdayDays = {
      Weekday.monday,
      Weekday.tuesday,
      Weekday.wednesday,
      Weekday.thursday,
      Weekday.friday,
    };
    if (set.length == 5 && weekdayDays.every(set.contains)) {
      return 'schedules.edit.shortcutWeekdays'.tr();
    }
    const weekendDays = {Weekday.saturday, Weekday.sunday};
    if (set.length == 2 && weekendDays.every(set.contains)) {
      return 'schedules.edit.shortcutWeekend'.tr();
    }
    // ISO tartibida tartiblab ko'rsatamiz.
    final sorted = weekdays.toList()..sort((a, b) => a.iso.compareTo(b.iso));
    return sorted.map((w) => w.label).join(', ');
  }

  /// Yangi `Schedule` yaratish — bitta yoki bir nechta maydonni
  /// o'zgartiradi.
  Schedule copyWith({
    String? id,
    String? parentUid,
    String? childId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      parentUid: parentUid ?? this.parentUid,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      type: type ?? this.type,
      weekdays: weekdays ?? this.weekdays,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isActive: isActive ?? this.isActive,
      blockedApps: blockedApps ?? this.blockedApps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
