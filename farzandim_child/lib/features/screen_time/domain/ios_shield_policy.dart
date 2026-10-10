// ─────────────────────────────────────────────────────────────────────
// IosShieldPolicy — backend jadvalidan iOS cheklov siyosati (sof mantiq)
// ─────────────────────────────────────────────────────────────────────
//
// Native tomonga faqat ilova nomlarisiz ma'lumot ketadi: "hammasini bloklash"
// va BLOCK vaqt oynalari. Qaysi ilovalar cheklanishini bola qurilmasida
// ota-ona FamilyActivityPicker orqali tanlaydi (Apple sharti — tanlov
// qurilmadan chiqmaydi). Semantika Android RestrictionsSyncService bilan
// bir xil: qurilma mahalliy vaqti, ISO hafta kunlari, yarim tundan
// o'tuvchi oynalar.

import 'package:flutter/foundation.dart';

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
  const IosShieldPolicy({required this.blockAll, required this.windows});

  /// DeviceActivitySchedule eng qisqa oralig'i (Apple: 15 daqiqa). Qisqaroq
  /// oyna uchun iOS jadval yaratmaydi — bunday oyna o'z vaqtida o'chmasdi.
  static const minWindowMinutes = 15;

  /// Faol BLOCK jadvallaridan siyosat. Noto'g'ri vaqt, bo'sh hafta kunlari
  /// yoki boshlanish == tugash bo'lgan oynalar tashlanadi (Android'da ham
  /// ular hech qachon bloklamaydi), [minWindowMinutes]dan qisqalari ham.
  factory IosShieldPolicy.fromBackend({
    required List<AppSchedulePolicy> schedules,
    required bool blockAll,
  }) {
    final windows = <ShieldWindow>[];
    for (final schedule in schedules) {
      if (!schedule.isActive || schedule.action != 'BLOCK') continue;
      final start = parseHhMm(schedule.startTime);
      final end = parseHhMm(schedule.endTime);
      if (start == null || end == null || start == end) continue;
      final weekdays = schedule.daysOfWeek
          .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
          .toSet()
          .toList()
        ..sort();
      if (weekdays.isEmpty) continue;
      final window =
          ShieldWindow(startMinute: start, endMinute: end, weekdays: weekdays);
      if (window.durationMinutes < minWindowMinutes) continue;
      windows.add(window);
    }
    return IosShieldPolicy(
      blockAll: blockAll,
      windows: List.unmodifiable(windows),
    );
  }

  final bool blockAll;
  final List<ShieldWindow> windows;

  Map<String, Object> toMap() => {
        'blockAll': blockAll,
        'windows': [for (final w in windows) w.toMap()],
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
      listEquals(other.windows, windows);

  @override
  int get hashCode => Object.hash(blockAll, Object.hashAll(windows));
}
