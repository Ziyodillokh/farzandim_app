// ─────────────────────────────────────────────────────────────────────
// RestrictionSnapshot — native RestrictionService o'qiydigan holat
// ─────────────────────────────────────────────────────────────────────
//
// Dart rejani hozirgi vaqtga qo'llab natijani prefs kalitlariga yozadi
// (native "flutter." prefiksi bilan o'qiydi). Kontrakt:
//   - har kalit FAQAT qiymati o'zgarganda yoziladi (har yozuv — butun XML
//     fayl + fsync);
//   - o'zgarish bo'lsa ENG OXIRIDA `restriction.snapshot_version` oshiriladi.
//     Native shu kalit o'zgarganda barcha kalitlarni bir yo'la qayta o'qiydi
//     (yarim yozilgan holatni ko'rmaydi);
//   - barcha epoch qiymatlar ISHONCHLI vaqtda (server soati). Native ularni
//     System.currentTimeMillis() + `restriction.clock_offset_ms` bilan
//     solishtiradi.
//
// `valid_until_ms` — natija shu lahzagacha to'g'ri (keyingi oyna chegarasi,
// 0 = vaqt chegarasi yo'q). Dart undan keyin 2 daqiqada qayta qo'llamasa,
// native `base_blocked_packages` (to'liq bloklar + "barchasini blokla")
// ga o'tadi va maktab blokini e'tiborsiz qoldiradi.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/app_restrictions/data/services/restriction_plan.dart';

/// Cheklov holati kalitlari (Dart nomlari; native `flutter.` qo'shadi).
abstract final class RestrictionKeys {
  static const blocked = 'restriction.blocked_packages';
  static const baseBlocked = 'restriction.base_blocked_packages';
  static const limits = 'restriction.limits';
  static const blockUnknown = 'restriction.block_unknown_sources';
  static const schoolPackages = 'restriction.school_packages';
  static const schoolCategories = 'restriction.school_categories';
  static const schoolAllowed = 'restriction.school_allowed';
  static const schoolUntil = 'restriction.school_until';
  static const schoolUntilMs = 'restriction.school_until_ms';
  static const validUntilMs = 'restriction.valid_until_ms';
  static const grants = 'restriction.grants';
  static const clockOffsetMs = 'restriction.clock_offset_ms';

  /// Eng oxirida yoziladi — native shu kalit o'zgarganda qayta o'qiydi.
  static const snapshotVersion = 'restriction.snapshot_version';

  /// Oxirgi muvaffaqiyatli reja (oflaynda qayta qo'llanadi).
  static const planCache = 'restriction.plan_cache';

  /// Oxirgi muvaffaqiyatli tarmoq olinishi (ishonchli epoch ms) — eng ko'pi
  /// bilan 10 daqiqada bir yoziladi.
  static const planFetchedAtMs = 'restriction.plan_fetched_at_ms';

  /// "O'chirishni taqiqlash" (Device Admin) — UI (resume'da) qo'llaydi.
  static const blockUninstall = 'restriction.block_uninstall';

  /// Eski versiya keshi — faqat zaxira sifatida o'qiladi.
  static const legacyBlockAllCache = 'restriction.block_all_apps_cache';

  /// Til matnlari (native overlay) — holat emas, tozalanmaydi.
  static const i18nPrefix = 'restriction.i18n.';
}

/// Soat siljishi shundan kam o'zgarsa qayta yozilmaydi (TrustedClock bilan bir xil).
const int kClockOffsetWriteThresholdMs = 30 * 1000;

@immutable
class RestrictionSnapshot {
  const RestrictionSnapshot({
    required this.blocked,
    required this.baseBlocked,
    required this.limits,
    required this.schoolPackages,
    required this.schoolCategories,
    required this.schoolAllowed,
    required this.schoolUntil,
    required this.schoolUntilMs,
    required this.validUntilMs,
    required this.grants,
    this.blockUnknown,
    this.clockOffsetMs,
  });

  final String blocked;
  final String baseBlocked;
  final String limits;
  final String schoolPackages;
  final String schoolCategories;
  final String schoolAllowed;

  /// Overlay matni uchun "HH:MM" (bo'sh — maktab bloki yo'q).
  final String schoolUntil;
  final int schoolUntilMs;
  final int validUntilMs;

  /// "paket:tugashEpochMs" vergul bilan.
  final String grants;

  /// `null` — noma'lum, kalitga tegilmaydi.
  final bool? blockUnknown;

  /// `null` — kalitga tegilmaydi.
  final int? clockOffsetMs;
}

/// Rejani [now] (ishonchli lahza) ga qo'llab native holatini hisoblaydi.
RestrictionSnapshot buildSnapshot(
  RestrictionPlan plan,
  DateTime now, {
  bool insideZone = true,
  int? clockOffsetMs,
}) {
  final outcome = applyPlan(plan, now, insideZone: insideZone);
  final school = outcome.school;
  final schoolEnd = school == null ? null : nextTashkentTime(now, school.until);
  final base = <String>{...plan.fullBlocks, if (plan.blockAll) kWildcardAll};
  final nowMs = now.millisecondsSinceEpoch;
  final grantUntil = <String, int>{};
  for (final g in plan.grants) {
    if (g.expiresAtMs <= nowMs) continue;
    final prev = grantUntil[g.packageName];
    if (prev == null || g.expiresAtMs > prev) {
      grantUntil[g.packageName] = g.expiresAtMs;
    }
  }
  return RestrictionSnapshot(
    blocked: _join(outcome.blocked),
    baseBlocked: _join(base),
    limits: _join(outcome.limits),
    schoolPackages: _join(school?.packages ?? const {}),
    schoolCategories: _join(school?.categories ?? const {}),
    schoolAllowed: _join(school?.allowedApps ?? const {}, separator: '\n'),
    schoolUntil: school?.until ?? '',
    schoolUntilMs: schoolEnd?.millisecondsSinceEpoch ?? 0,
    validUntilMs: nextBoundary(plan, now)?.millisecondsSinceEpoch ?? 0,
    grants: _join([for (final e in grantUntil.entries) '${e.key}:${e.value}']),
    blockUnknown: plan.blockUnknown,
    clockOffsetMs: clockOffsetMs,
  );
}

/// Faqat o'zgargan kalitlarni yozadi, o'zgarish bo'lsa `snapshot_version`
/// ni ENG OXIRIDA oshiradi. Yozilgan kalitlar ro'yxati (tartibda) qaytadi.
Future<List<String>> writeSnapshot(
  SharedPreferences prefs,
  RestrictionSnapshot s,
) async {
  final written = <String>[];
  Future<void> putString(String key, String value) async {
    if (prefs.get(key) == value) return;
    await prefs.setString(key, value);
    written.add(key);
  }

  Future<void> putInt(String key, int value) async {
    if (prefs.get(key) == value) return;
    await prefs.setInt(key, value);
    written.add(key);
  }

  Future<void> writeSchool() async {
    await putString(RestrictionKeys.schoolPackages, s.schoolPackages);
    await putString(RestrictionKeys.schoolCategories, s.schoolCategories);
    await putString(RestrictionKeys.schoolAllowed, s.schoolAllowed);
    await putString(RestrictionKeys.schoolUntil, s.schoolUntil);
    await putInt(RestrictionKeys.schoolUntilMs, s.schoolUntilMs);
  }

  // Eski native (snapshot_version'siz) uchun ham tartib: dars boshlanishida
  // maktab kalitlari `blocked` dan OLDIN (overlay "Dars vaqti" bo'lsin),
  // tugashida — keyin.
  final isSchoolStarting = s.schoolUntil.isNotEmpty;
  if (isSchoolStarting) await writeSchool();
  await putString(RestrictionKeys.blocked, s.blocked);
  await putString(RestrictionKeys.baseBlocked, s.baseBlocked);
  await putString(RestrictionKeys.limits, s.limits);
  if (!isSchoolStarting) await writeSchool();
  final blockUnknown = s.blockUnknown;
  if (blockUnknown != null &&
      prefs.get(RestrictionKeys.blockUnknown) != blockUnknown) {
    await prefs.setBool(RestrictionKeys.blockUnknown, blockUnknown);
    written.add(RestrictionKeys.blockUnknown);
  }
  await putString(RestrictionKeys.grants, s.grants);
  await putInt(RestrictionKeys.validUntilMs, s.validUntilMs);
  final offset = s.clockOffsetMs;
  if (offset != null) {
    final stored = prefs.get(RestrictionKeys.clockOffsetMs);
    if (stored is! int ||
        (stored - offset).abs() > kClockOffsetWriteThresholdMs) {
      await prefs.setInt(RestrictionKeys.clockOffsetMs, offset);
      written.add(RestrictionKeys.clockOffsetMs);
    }
  }
  if (written.isNotEmpty) {
    final previous = prefs.get(RestrictionKeys.snapshotVersion);
    await prefs.setInt(
      RestrictionKeys.snapshotVersion,
      (previous is int ? previous : 0) + 1,
    );
    written.add(RestrictionKeys.snapshotVersion);
  }
  return written;
}

/// Unpair: barcha cheklov holati (restriction.*, school_zone.*, game.pending,
/// native limit_warned) o'chiriladi. Til matnlari (restriction.i18n.*) holat
/// emas — qoladi. `snapshot_version` ENG OXIRIDA o'chiriladi.
Future<void> clearRestrictionState(SharedPreferences prefs) async {
  try {
    // Native va boshqa isolate yozgan kalitlar (limit_warned, game.pending)
    // ham ko'rinsin.
    await prefs.reload();
  } catch (e) {
    debugPrint('clearRestrictionState: reload xato: $e');
  }
  final keys = prefs.getKeys().where(_isEnforcementKey).toList()
    ..remove(RestrictionKeys.snapshotVersion);
  for (final key in keys) {
    await prefs.remove(key);
  }
  await prefs.remove(RestrictionKeys.snapshotVersion);
}

bool _isEnforcementKey(String key) =>
    (key.startsWith('restriction.') &&
        !key.startsWith(RestrictionKeys.i18nPrefix)) ||
    key.startsWith('school_zone.') ||
    key == 'game.pending';

String _join(Iterable<String> values, {String separator = ','}) =>
    (values.where((v) => v.isNotEmpty).toSet().toList()..sort()).join(
      separator,
    );
