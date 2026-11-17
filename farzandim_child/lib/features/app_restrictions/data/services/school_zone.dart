// ─────────────────────────────────────────────────────────────────────
// School zone — telefon maktab hududidami (School Mode «faqat hududda»)
// ─────────────────────────────────────────────────────────────────────
//
// Qaror QURILMANING o'zida: LocationService har joylashuv nuqtasini prefs'ga
// yozadi (`recordFix`), cheklov sync'i shu nuqta bilan hududni tekshiradi
// (yangi nuqta kelganda, ekran yoqilganda, 5 daqiqalik tick'da va chiqish
// kutish muddati tugaganda). Joylashuv maktabga bu maqsadda yuborilmaydi.
//
// Qoidalar (`decideZone`):
//   - joylashuv o'chiq / nuqta yo'q yoki 20 daqiqadan eski → HUDUDDA deb
//     hisoblanadi (fail-closed: GPS'ni o'chirib blokdan qochib bo'lmaydi;
//     bu holda dars vaqti bo'yicha bloklanadi — avvalgidek);
//   - aniqligi 150 m dan yomon nuqta — hech narsa o'zgarmaydi;
//   - kirish: masofa ≤ radius + aniqlik (50 m gacha);
//   - chiqish: masofa > radius + 50 m + aniqlik va 3 daqiqa davomida —
//     chegarada GPS sakrashi blokni yoqib-o'chirib turmasin. Hech qachon
//     hududda bo'lmagan (uydagi) telefon darhol "tashqarida".

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/schedules/data/models/school_mode_meta.dart';

/// Shundan yomon aniqlikdagi nuqta hudud qaroriga ishlatilmaydi.
const double kZoneMaxAccuracyM = 150;

/// Aniqlik shu miqdorgacha masofaga "imtiyoz" sifatida qo'shiladi.
const double kZoneAccuracyAllowanceM = 50;

/// Chiqish chegarasi radiusdan shuncha tashqarida (gisterezis).
const double kZoneExitMarginM = 50;

/// Chiqish shuncha vaqt davom etsa — blok yechiladi.
const Duration kZoneExitDwell = Duration(minutes: 3);

/// Shundan eski nuqta — "bilmayman" (fail-closed).
const Duration kZoneFixMaxAge = Duration(minutes: 20);

@immutable
class ZoneFix {
  const ZoneFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.at,
  });

  static ZoneFix? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    final acc = json['acc'];
    final at = DateTime.tryParse('${json['at']}');
    if (lat is! num || lng is! num || acc is! num || at == null) return null;
    return ZoneFix(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      accuracyM: acc.toDouble(),
      at: at,
    );
  }

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'acc': accuracyM,
    'at': at.toUtc().toIso8601String(),
  };
}

/// Oxirgi qaror va "tashqarida" boshlangan vaqt (gisterezis xotirasi).
@immutable
class ZoneMemory {
  const ZoneMemory({this.inside, this.outsideSince});

  static ZoneMemory fromJson(Object? json) {
    if (json is! Map) return const ZoneMemory();
    final inside = json['inside'];
    return ZoneMemory(
      inside: inside is bool ? inside : null,
      outsideSince: DateTime.tryParse('${json['outsideSince']}'),
    );
  }

  /// `null` — hali hech qanday aniq qaror bo'lmagan.
  final bool? inside;
  final DateTime? outsideSince;

  Map<String, dynamic> toJson() => {
    'inside': inside,
    'outsideSince': outsideSince?.toUtc().toIso8601String(),
  };
}

@immutable
class ZoneDecision {
  const ZoneDecision({required this.inside, required this.memory});

  /// Blok qo'llansinmi (hududda yoki bilib bo'lmaydi).
  final bool inside;
  final ZoneMemory memory;
}

/// Ikki nuqta orasidagi masofa (metr, haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earth * math.asin(math.min(1, math.sqrt(a)));
}

/// Telefon hududdami — sof funksiya (vaqt va joylashuv tashqaridan).
ZoneDecision decideZone({
  required SchoolZone zone,
  required ZoneFix? fix,
  required ZoneMemory memory,
  required DateTime now,
  required bool locationOn,
}) {
  // Bilib bo'lmaydi → hududda (dars vaqti bo'yicha blok, avvalgidek).
  if (!locationOn || fix == null || now.difference(fix.at) > kZoneFixMaxAge) {
    return ZoneDecision(inside: true, memory: memory);
  }
  // Juda noaniq nuqta — oldingi qaror saqlanadi.
  if (fix.accuracyM <= 0 || fix.accuracyM > kZoneMaxAccuracyM) {
    return ZoneDecision(inside: memory.inside ?? true, memory: memory);
  }
  final distance = distanceMeters(
    fix.latitude,
    fix.longitude,
    zone.latitude,
    zone.longitude,
  );
  final allowance = math.min(fix.accuracyM, kZoneAccuracyAllowanceM);
  if (distance <= zone.radiusM + allowance) {
    return const ZoneDecision(inside: true, memory: ZoneMemory(inside: true));
  }
  if (distance > zone.radiusM + kZoneExitMarginM + allowance) {
    // Hududda bo'lmagan (uydagi) telefon — darhol tashqarida.
    if (memory.inside != true) {
      return const ZoneDecision(
        inside: false,
        memory: ZoneMemory(inside: false),
      );
    }
    final since = memory.outsideSince ?? now;
    if (now.difference(since) >= kZoneExitDwell) {
      return const ZoneDecision(
        inside: false,
        memory: ZoneMemory(inside: false),
      );
    }
    return ZoneDecision(
      inside: true,
      memory: ZoneMemory(inside: true, outsideSince: since),
    );
  }
  // Chegara oralig'i — oldingi qaror (noma'lum bo'lsa — hududda).
  return ZoneDecision(
    inside: memory.inside ?? true,
    memory: ZoneMemory(inside: memory.inside),
  );
}

/// Hudud nuqtasi va xotirasi — SharedPreferences (bg va UI isolate'lar
/// bir faylni o'qiydi, shuning uchun o'qishdan oldin `reload`).
abstract final class SchoolZoneStore {
  static const fixKey = 'school_zone.fix';
  static const memoryKey = 'school_zone.memory';

  /// Shu isolate'da oxirgi yozilgan nuqta — deyarli bir xil nuqtalar har
  /// safar butun prefs faylini qayta yozmasin.
  static ZoneFix? _lastWritten;

  /// Yangi nuqta yozilganda (shu isolate'da) chaqiriladi — cheklov sync'i
  /// hudud oynasi faol bo'lsa qarorni darhol qayta hisoblaydi.
  static final List<void Function()> _listeners = [];

  static void addFixListener(void Function() listener) =>
      _listeners.add(listener);

  static void removeFixListener(void Function() listener) =>
      _listeners.remove(listener);

  /// LocationService har nuqtada chaqiradi (aniqligi yomon bo'lsa ham —
  /// qarorda filtrlanadi). Xato jim (joylashuv yozuvini buzmaydi).
  static Future<void> recordFix({
    required double latitude,
    required double longitude,
    required double accuracyM,
    required DateTime at,
  }) async {
    final fix = ZoneFix(
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      at: at,
    );
    if (_isRedundant(fix)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(fixKey, jsonEncode(fix.toJson()));
      _lastWritten = fix;
    } catch (e) {
      debugPrint('SchoolZoneStore.recordFix: $e');
      return;
    }
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('SchoolZoneStore listener xato: $e');
      }
    }
  }

  /// Oxirgi yozilgandan 30 s ichida, 25 m dan kam siljigan va aniqligi
  /// sezilarli yaxshilanmagan nuqta — qarorni o'zgartirmaydi.
  static bool _isRedundant(ZoneFix fix) {
    final last = _lastWritten;
    if (last == null) return false;
    final age = fix.at.difference(last.at);
    if (age.isNegative || age > const Duration(seconds: 30)) return false;
    if (fix.accuracyM * 2 < last.accuracyM) return false;
    return distanceMeters(
          fix.latitude,
          fix.longitude,
          last.latitude,
          last.longitude,
        ) <
        25;
  }

  @visibleForTesting
  static void debugReset() {
    _lastWritten = null;
    _listeners.clear();
  }

  static ZoneFix? readFix(SharedPreferences prefs) =>
      ZoneFix.tryFromJson(_decode(prefs.getString(fixKey)));

  static ZoneMemory readMemory(SharedPreferences prefs) =>
      ZoneMemory.fromJson(_decode(prefs.getString(memoryKey)));

  /// Faqat o'zgarganda yoziladi (har yozuv — butun prefs fayli).
  static Future<void> writeMemory(
    SharedPreferences prefs,
    ZoneMemory memory,
  ) async {
    final raw = jsonEncode(memory.toJson());
    if (prefs.getString(memoryKey) == raw) return;
    await prefs.setString(memoryKey, raw);
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
