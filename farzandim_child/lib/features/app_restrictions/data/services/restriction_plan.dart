// ─────────────────────────────────────────────────────────────────────
// RestrictionPlan — tarmoqdan olingan cheklovlar va ularni qo'llash
// ─────────────────────────────────────────────────────────────────────
//
// Reja = ota-ona limitlari, vaqt oynalari (AppSchedulePolicy), jadvallar
// (Routine, maktab School Mode jadvali ham), "barchasini blokla" va ota-ona
// tasdiqlagan qo'shimcha vaqt (grant). U muvaffaqiyatli sync'da prefs'ga
// saqlanadi. Internet bo'lmasa OXIRGI reja hozirgi vaqtga QAYTA qo'llanadi —
// shu sabab bola aviarejimni yoqib dars boshlanishini chetlab o'ta olmaydi.
//
// VAQT: barcha funksiyalar `now` ni ANIQ LAHZA (instant) deb oladi va oynalarni
// Asia/Tashkent (UTC+5, DST yo'q) devor vaqtida baholaydi — qurilma vaqt
// mintaqasi noto'g'ri bo'lsa ham natija bir xil. Chaqiruvchi `now` sifatida
// ishonchli soatni (TrustedClock) beradi.
//
// Kesh JSON'i barqaror (kanonik tartib, `fetchedAt` YO'Q): bir xil reja har
// sync'da bir xil satr beradi → prefs fayli behuda qayta yozilmaydi.
//
// `applyPlan` / `nextBoundary` — sof funksiyalar: testlanadi.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:farzandim_child/core/utils/tashkent_time.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/models/school_mode_meta.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

const String kWildcardAll = '*';

/// Ota-ona tasdiqlagan qo'shimcha vaqt: paket shu lahzagacha ochiq
/// (ishonchli vaqt, epoch ms).
@immutable
class PlanGrant {
  const PlanGrant({required this.packageName, required this.expiresAtMs});

  static PlanGrant? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final pkg = json['pkg'];
    final until = json['until'];
    if (pkg is! String || pkg.isEmpty || until is! num) return null;
    return PlanGrant(packageName: pkg, expiresAtMs: until.toInt());
  }

  final String packageName;
  final int expiresAtMs;

  Map<String, dynamic> toJson() => {'pkg': packageName, 'until': expiresAtMs};
}

@immutable
class RestrictionPlan {
  const RestrictionPlan({
    required this.fullBlocks,
    required this.limitEntries,
    required this.policies,
    required this.routines,
    required this.blockAll,
    required this.planDay,
    this.grants = const [],
    this.blockUnknown,
    this.blockUninstall,
  });

  static RestrictionPlan? tryFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RestrictionPlan(
        fullBlocks: _strings(json['fullBlocks']),
        limitEntries: _strings(json['limitEntries']),
        policies: ((json['policies'] as List?) ?? const [])
            .map(
              (e) =>
                  AppSchedulePolicy.fromBackendJson(e as Map<String, dynamic>),
            )
            .toList(growable: false),
        routines: ((json['routines'] as List?) ?? const [])
            .map((e) => Schedule.fromBackendJson(e as Map<String, dynamic>))
            .toList(growable: false),
        blockAll: json['blockAll'] == true,
        planDay: _planDayFromJson(json),
        grants: ((json['grants'] as List?) ?? const [])
            .map(PlanGrant.tryFromJson)
            .whereType<PlanGrant>()
            .toList(growable: false),
        blockUnknown: json['blockUnknown'] as bool?,
        blockUninstall: json['blockUninstall'] as bool?,
      );
    } catch (e) {
      debugPrint('RestrictionPlan: kesh o\'qilmadi ($e)');
      return null;
    }
  }

  /// To'liq bloklangan paketlar (kunlik limit 0).
  final List<String> fullBlocks;

  /// Vaqt cheklovlari "paket:daqiqa".
  final List<String> limitEntries;
  final List<AppSchedulePolicy> policies;
  final List<Schedule> routines;
  final bool blockAll;

  /// Reja olingan Toshkent kuni "YYYY-MM-DD". Maktab jadvali faqat shu kuni
  /// amal qiladi (server uni shu kun uchun hisoblaydi).
  final String planDay;

  /// Faol qo'shimcha vaqtlar (paket bo'yicha).
  final List<PlanGrant> grants;

  /// "Notanish manbalardan ilovalar" — `null`: hali bilinmaydi.
  final bool? blockUnknown;

  /// "O'chirishni taqiqlash" (Device Admin) — UI qo'llaydi. `null`: bilinmaydi.
  final bool? blockUninstall;

  /// Kanonik JSON: ro'yxatlar tartiblangan, vaqt belgisi yo'q — bir xil reja
  /// doim bir xil satr.
  String toJsonString() {
    final policies = [...this.policies]..sort(_comparePolicy);
    final routines = [...this.routines]..sort((a, b) => a.id.compareTo(b.id));
    final grants = [...this.grants]
      ..sort((a, b) {
        final byPkg = a.packageName.compareTo(b.packageName);
        return byPkg != 0 ? byPkg : a.expiresAtMs.compareTo(b.expiresAtMs);
      });
    return jsonEncode({
      'fullBlocks': [...fullBlocks]..sort(),
      'limitEntries': [...limitEntries]..sort(),
      'policies': [
        for (final p in policies)
          {
            'id': p.id,
            'name': p.name,
            'startTime': p.startTime,
            'endTime': p.endTime,
            'daysOfWeek': p.daysOfWeek,
            'action': p.action,
            'isActive': p.isActive,
          },
      ],
      'routines': [for (final r in routines) r.toBackendJson()],
      'blockAll': blockAll,
      'planDay': planDay,
      'grants': [for (final g in grants) g.toJson()],
      'blockUnknown': blockUnknown,
      'blockUninstall': blockUninstall,
    });
  }

  static int _comparePolicy(AppSchedulePolicy a, AppSchedulePolicy b) {
    final byId = a.id.compareTo(b.id);
    if (byId != 0) return byId;
    final byStart = a.startTime.compareTo(b.startTime);
    return byStart != 0 ? byStart : a.endTime.compareTo(b.endTime);
  }

  /// Eski kesh (`fetchedAt` bilan) — kun undan Toshkent bo'yicha olinadi.
  static String _planDayFromJson(Map<String, dynamic> json) {
    final day = json['planDay'];
    if (day is String) return day;
    final fetchedAt = DateTime.tryParse('${json['fetchedAt']}');
    return fetchedAt == null ? '' : tashkentDayKey(fetchedAt);
  }

  static List<String> _strings(Object? raw) =>
      raw is List ? raw.map((e) => '$e').toList(growable: false) : const [];
}

/// Dars vaqtidagi maktab bloki (overlay matni va toifa bo'yicha blok uchun).
@immutable
class SchoolBlock {
  const SchoolBlock({
    required this.packages,
    required this.categories,
    required this.allowedApps,
    required this.until,
  });

  final Set<String> packages;
  final Set<String> categories;

  /// Ruxsat etilgan ilovalar nomi — kichik harfda, bo'shliqlar yig'ilgan.
  final Set<String> allowedApps;

  /// Blok tugash vaqti "HH:MM" (Toshkent).
  final String until;
}

@immutable
class RestrictionOutcome {
  const RestrictionOutcome({
    required this.blocked,
    required this.limits,
    this.school,
  });

  final Set<String> blocked;
  final List<String> limits;

  /// `null` — hozir maktab bloki yo'q (dars emas, hududdan tashqarida va h.k.).
  final SchoolBlock? school;
}

/// Toshkent kun kaliti "YYYY-MM-DD" (lahza bo'yicha).
String tashkentDayKey(DateTime instant) {
  final t = toTashkent(instant);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

/// [instant] dan keyingi birinchi Toshkent [hhmm] lahzasi (bugun yoki ertaga).
DateTime? nextTashkentTime(DateTime instant, String hhmm) {
  final minutes = _parseHhMm(hhmm);
  if (minutes == null) return null;
  final today = _tashkentMidnight(instant).add(Duration(minutes: minutes));
  return today.isAfter(instant) ? today : today.add(const Duration(days: 1));
}

/// Maktab jadvali faqat olingan kunida amal qiladi: server uni shu kun uchun
/// hisoblaydi (bayram, istisno, favqulodda holat). Uzoq oflayn telefonda
/// o'tgan haftaning jadvali shu hafta kunida qayta yoqilmasin.
bool _isPlanDay(RestrictionPlan plan, DateTime now) =>
    plan.planDay.isNotEmpty && plan.planDay == tashkentDayKey(now);

/// Hozir faol va hudud talab qiladigan maktab jadvalining hududi (yo'q — null).
SchoolZone? activeSchoolZone(RestrictionPlan plan, DateTime now) {
  if (!_isPlanDay(plan, now)) return null;
  for (final r in plan.routines) {
    if (r.isSchoolMode &&
        isRoutineActive(r, now) &&
        r.schoolMode?.zone != null) {
      return r.schoolMode!.zone;
    }
  }
  return null;
}

/// Rejani hozirgi vaqtga qo'llash. [insideZone] — hudud qarori (hudud talab
/// qilinmasa e'tiborga olinmaydi).
RestrictionOutcome applyPlan(
  RestrictionPlan plan,
  DateTime now, {
  bool insideZone = true,
}) {
  final blocked = <String>{...plan.fullBlocks};
  if (plan.blockAll || isWindowBlocked(plan.policies, now)) {
    blocked.add(kWildcardAll);
  }
  final schoolPackages = <String>{};
  final categories = <String>{};
  final allowed = <String>{};
  String? until;
  final schoolToday = _isPlanDay(plan, now);
  for (final r in plan.routines) {
    if (!isRoutineActive(r, now)) continue;
    if (r.isSchoolMode) {
      if (!schoolToday) continue;
      final meta = r.schoolMode;
      if (meta?.zone != null && !insideZone) continue;
      schoolPackages.addAll(r.blockedApps);
      categories.addAll(meta?.blockedCategories ?? const []);
      allowed.addAll((meta?.allowedApps ?? const []).map(normalizeAppName));
      final end = _hhmm(r.endHour, r.endMinute);
      if (until == null || end.compareTo(until) > 0) until = end;
    }
    blocked.addAll(r.blockedApps);
  }
  final school = until == null
      ? null
      : SchoolBlock(
          packages: schoolPackages,
          categories: categories,
          allowedApps: allowed,
          until: until,
        );
  return RestrictionOutcome(
    blocked: blocked,
    limits: plan.limitEntries,
    school: school,
  );
}

/// Natija keyingi marta qachon o'zgaradi (oyna boshlanishi/tugashi, maktab
/// kuni almashishi). Vaqtga bog'liq qoida bo'lmasa — `null`. Hudud qarori
/// hisobga olinmaydi (u joylashuvga bog'liq, vaqtga emas).
DateTime? nextBoundary(RestrictionPlan plan, DateTime now) {
  final current = _timeSignature(plan, now);
  for (final candidate in _boundaryCandidates(plan, now)) {
    if (_timeSignature(plan, candidate) != current) return candidate;
  }
  return null;
}

/// Natija faqat oyna boshi/oxiri daqiqalarida va Toshkent yarim tunida
/// o'zgarishi mumkin — shu lahzalar (8 kun oldinga, o'sish tartibida).
List<DateTime> _boundaryCandidates(RestrictionPlan plan, DateTime now) {
  final minutes = <int>{0};
  for (final p in plan.policies) {
    if (!p.isActive || p.action != 'BLOCK') continue;
    final start = _parseHhMm(p.startTime);
    final end = _parseHhMm(p.endTime);
    if (start == null || end == null) continue;
    minutes
      ..add(start)
      ..add(end);
  }
  for (final r in plan.routines) {
    if (!r.isActive) continue;
    minutes
      ..add(r.startHour * 60 + r.startMinute)
      ..add(r.endHour * 60 + r.endMinute);
  }
  final midnight = _tashkentMidnight(now);
  final sorted = minutes.toList()..sort();
  return [
    for (var day = 0; day <= 7; day++)
      for (final m in sorted) midnight.add(Duration(days: day, minutes: m)),
  ].where((c) => c.isAfter(now)).toList(growable: false);
}

String _timeSignature(RestrictionPlan plan, DateTime at) {
  final o = applyPlan(plan, at);
  final school = o.school;
  return [
    (o.blocked.toList()..sort()).join(','),
    if (school != null) ...[
      (school.packages.toList()..sort()).join(','),
      (school.categories.toList()..sort()).join(','),
      (school.allowedApps.toList()..sort()).join(','),
      school.until,
    ],
  ].join('|');
}

/// Ilova nomini solishtirish uchun (server bilan bir xil: kichik harf, bo'shliqlar).
String normalizeAppName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Jadval hozir faolmi: yoqilgan, kun va vaqt oynasi ichida (Toshkent).
bool isRoutineActive(Schedule r, DateTime now) {
  if (!r.isActive) return false;
  return _isActiveAt(
    days: {for (final w in r.weekdays) w.index + 1},
    startMin: r.startHour * 60 + r.startMinute,
    endMin: r.endHour * 60 + r.endMinute,
    at: toTashkent(now),
  );
}

/// Hozir ota-onaning BLOCK vaqt oynasi ichidami (Toshkent).
bool isWindowBlocked(List<AppSchedulePolicy> policies, DateTime now) {
  final at = toTashkent(now);
  for (final p in policies) {
    if (!p.isActive || p.action != 'BLOCK') continue;
    final start = _parseHhMm(p.startTime);
    final end = _parseHhMm(p.endTime);
    if (start == null || end == null) continue;
    if (_isActiveAt(
      days: p.daysOfWeek.toSet(),
      startMin: start,
      endMin: end,
      at: at,
    )) {
      return true;
    }
  }
  return false;
}

/// Oyna [at] (Toshkent devor vaqti) da faolmi. Kechadan ertalabga o'tuvchi
/// oynaning yarim tundan KEYINGI qismi oyna BOSHLANGAN (kechagi) kunga
/// tegishli: "Juma 21:00–07:00" shanba 00:00–07:00 ni ham qamraydi, dushanba
/// 00:00–07:00 ni esa (yakshanba tanlanmagan bo'lsa) qamramaydi.
bool _isActiveAt({
  required Set<int> days,
  required int startMin,
  required int endMin,
  required DateTime at,
}) {
  final minute = at.hour * 60 + at.minute;
  if (!isInWindow(minute, startMin, endMin)) return false;
  if (startMin < endMin || minute >= startMin) {
    return days.contains(at.weekday);
  }
  final yesterday = at.weekday == DateTime.monday ? 7 : at.weekday - 1;
  return days.contains(yesterday);
}

/// Vaqt oynasi ichidami (kechadan ertalabga o'tuvchi oyna ham).
bool isInWindow(int nowMinutes, int startMin, int endMin) {
  if (startMin == endMin) return false;
  if (startMin < endMin) return nowMinutes >= startMin && nowMinutes < endMin;
  return nowMinutes >= startMin || nowMinutes < endMin;
}

/// Toshkent yarim tuni (lahza) — [instant] tushgan kun boshi.
DateTime _tashkentMidnight(DateTime instant) {
  final t = toTashkent(instant);
  return DateTime.utc(t.year, t.month, t.day).subtract(tashkentOffset);
}

int? _parseHhMm(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String _hhmm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
