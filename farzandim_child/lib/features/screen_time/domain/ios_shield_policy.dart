// ─────────────────────────────────────────────────────────────────────
// IosShieldPolicy — backend jadvalidan iOS cheklov siyosati (sof mantiq)
// ─────────────────────────────────────────────────────────────────────
//
// Native tomonga faqat ilova nomlarisiz ma'lumot ketadi: "hammasini bloklash",
// BLOCK vaqt oynalari va kunlik limit. Qaysi ilovalar cheklanishini bola
// qurilmasida ota-ona FamilyActivityPicker orqali tanlaydi (Apple sharti —
// tanlov qurilmadan chiqmaydi). Semantika Android RestrictionsSyncService
// bilan bir xil: qurilma mahalliy vaqti, ISO hafta kunlari, yarim tundan
// o'tuvchi oynalar.
//
// Ota-ona ilovasi (Android) iPhone ilovalarini ko'rmaydi, shuning uchun bola
// "o'rnatilgan ilovalar" ro'yxatiga bitta virtual element yuboradi —
// [selectionPackage] ("iPhone: tanlangan ilovalar"). Ota-ona uni oddiy ilova
// kabi boshqaradi va bu yerda tanlovga qo'llanadi:
//   • app-limit dailyLimitMs = 0  → doim bloklash;
//   • app-limit dailyLimitMs > 0  → tanlangan ilovalarga kunlik limit;
//   • Rejim (Routine) blockedApps'ida bo'lsa → shu rejim oynasida bloklash.

import 'package:flutter/foundation.dart';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

@immutable
class ShieldWindow {
  const ShieldWindow({
    required this.startMinute,
    required this.endMinute,
    required this.weekdays,
  });

  /// 0..1439 — kun boshidan daqiqalar.
  final int startMinute;
  final int endMinute;

  /// ISO: 1 = dushanba ... 7 = yakshanba.
  final List<int> weekdays;

  /// Davomiylik daqiqada (yarim tundan o'tuvchi oynalar ham).
  int get durationMinutes => (endMinute - startMinute + 1440) % 1440;

  Map<String, Object> toMap() => {
        'start': startMinute,
        'end': endMinute,
        'weekdays': weekdays,
      };

  @override
  bool operator ==(Object other) =>
      other is ShieldWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      listEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(startMinute, endMinute, Object.hashAll(weekdays));
}

@immutable
class IosShieldPolicy {
  const IosShieldPolicy({
    required this.blockAll,
    required this.windows,
    this.dailyLimitMinutes,
    this.denyAppRemoval = false,
  });

  /// Ota-ona ro'yxatidagi virtual "iPhone: tanlangan ilovalar" elementi.
  static const selectionPackage = 'uz.parvoz.growth.ios-selected-apps';

  static const _minutesPerDay = 1440;

  /// DeviceActivitySchedule eng qisqa oralig'i (Apple: 15 daqiqa). Qisqaroq
  /// oyna uchun iOS jadval yaratmaydi — bunday oyna o'z vaqtida o'chmasdi.
  static const minWindowMinutes = 15;

  /// Faol BLOCK jadvallaridan siyosat. Noto'g'ri vaqt, bo'sh hafta kunlari
  /// yoki boshlanish == tugash bo'lgan oynalar tashlanadi (Android'da ham
  /// ular hech qachon bloklamaydi), [minWindowMinutes]dan qisqalari ham.
  ///
  /// [routines] — faqat blockedApps'ida [selectionPackage] bo'lgan faol
  /// rejimlar oynaga aylanadi. [limits] dan [selectionPackage] limiti:
  /// 0 — doim bloklash, > 0 — kunlik limit (daqiqaga yuqoriga yaxlitlanadi).
  factory IosShieldPolicy.fromBackend({
    required List<AppSchedulePolicy> schedules,
    required bool blockAll,
    List<Schedule> routines = const [],
    List<AppLimit> limits = const [],
    bool denyAppRemoval = false,
  }) {
    final windows = <ShieldWindow>[
      for (final schedule in schedules)
        if (schedule.isActive && schedule.action == 'BLOCK')
          ?_window(
            parseHhMm(schedule.startTime),
            parseHhMm(schedule.endTime),
            schedule.daysOfWeek,
          ),
      for (final routine in routines)
        if (routine.isActive && routine.blockedApps.contains(selectionPackage))
          ?_window(
            routine.startHour * 60 + routine.startMinute,
            routine.endHour * 60 + routine.endMinute,
            [for (final day in routine.weekdays) day.index + 1],
          ),
    ];
    final selectionLimit = limits
        .where((l) => l.isActive && l.packageName == selectionPackage)
        .firstOrNull;
    final limitMs = selectionLimit?.dailyLimitMs;
    return IosShieldPolicy(
      blockAll: blockAll || limitMs == 0,
      windows: List.unmodifiable(windows),
      dailyLimitMinutes: limitMs == null || limitMs <= 0
          ? null
          : (limitMs / Duration.millisecondsPerMinute)
              .ceil()
              .clamp(1, _minutesPerDay - 1),
      denyAppRemoval: denyAppRemoval,
    );
  }

  /// Noto'g'ri vaqt, bo'sh hafta kunlari, boshlanish == tugash yoki
  /// [minWindowMinutes]dan qisqa oyna — `null` (Android'da ham bloklamaydi).
  static ShieldWindow? _window(int? start, int? end, Iterable<int> days) {
    if (start == null || end == null || start == end) return null;
    if (start < 0 || start >= _minutesPerDay) return null;
    if (end < 0 || end >= _minutesPerDay) return null;
    final weekdays = days
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
    if (weekdays.isEmpty) return null;
    final window =
        ShieldWindow(startMinute: start, endMinute: end, weekdays: weekdays);
    return window.durationMinutes < minWindowMinutes ? null : window;
  }

  final bool blockAll;
  final List<ShieldWindow> windows;

  /// Tanlangan ilovalarga kunlik limit (daqiqa); `null` — limit yo'q.
  final int? dailyLimitMinutes;

  /// Ota-onaning "O'chirishdan himoya"si (device-policy `blockUninstall`):
  /// iPhone'da ilovalarni (Parvoz ham) o'chirish taqiqlanadi.
  final bool denyAppRemoval;

  Map<String, Object> toMap() => {
        'blockAll': blockAll,
        'windows': [for (final w in windows) w.toMap()],
        if (dailyLimitMinutes != null) 'dailyLimitMinutes': dailyLimitMinutes!,
        'denyAppRemoval': denyAppRemoval,
      };

  /// "HH:MM" → kun boshidan daqiqa; noto'g'ri bo'lsa null.
  static int? parseHhMm(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  @override
  bool operator ==(Object other) =>
      other is IosShieldPolicy &&
      other.blockAll == blockAll &&
      other.dailyLimitMinutes == dailyLimitMinutes &&
      other.denyAppRemoval == denyAppRemoval &&
      listEquals(other.windows, windows);

  @override
  int get hashCode =>
      Object.hash(
        blockAll,
        dailyLimitMinutes,
        denyAppRemoval,
        Object.hashAll(windows),
      );
}
