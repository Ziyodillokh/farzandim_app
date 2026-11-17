// ─────────────────────────────────────────────────────────────────────
// TrustedClock — server vaqtiga tayangan "ishonchli" soat
// ─────────────────────────────────────────────────────────────────────
//
// Bola sozlamalarda sana/vaqtni o'zgartirsa ham jadval oynalari, School
// Mode va kunlik limit kuni server vaqtiga tayanadi (fn-clock-bypass).
//
//   now() = DateTime.now() + offset
//
// offset = serverVaqt − qurilma soati; umumiy backend Dio'dagi
// ClockSyncInterceptor HTTP `Date` sarlavhalaridan o'rganadi: oxirgi
// [TrustedClock.windowSize] namunaning medianasi, javobi
// [TrustedClock.maxRoundTrip] dan uzoq kelgan so'rovlar hisobga olinmaydi.
// Soat o'zgartirilsa yangi javoblar uni bir necha so'rovda tuzatadi.
//
// Prefs `restriction.clock_offset_ms` (int, ms; native RestrictionService
// o'qiydi) isolate ishga tushganda O'QILADI. Uni restriction snapshot
// (BackgroundJobs egasi) `snapshot_version` bilan birga YOZADI — ikki yozuvchi
// bo'lsa snapshot "o'zgarmadi" deb versiyani oshirmay qolardi. Offset 30 s
// dan ko'p siljisa [TrustedClock.offsetChanges] xabar beradi (snapshot qayta
// qo'llansin).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class TrustedClock {
  /// Native o'qiydigan kalit (Dart nomi; native `flutter.` qo'shadi).
  static const prefsKey = 'restriction.clock_offset_ms';

  /// Shundan kam siljish "o'zgarish" emas (prefs yozuvi va xabar yo'q).
  static const changeThreshold = Duration(seconds: 30);

  /// Bundan uzoq davom etgan javoblar namunaga olinmaydi.
  static const maxRoundTrip = Duration(seconds: 5);

  /// Mediana olinadigan oxirgi namunalar soni.
  static const windowSize = 5;

  static int _offsetMs = 0;
  static int _announcedMs = 0;
  static final List<int> _samples = [];
  static Future<void>? _loading;
  static final StreamController<int> _changes =
      StreamController<int>.broadcast();

  /// Ishonchli vaqt − qurilma soati (ms). Noma'lum bo'lsa 0.
  static int get offsetMs => _offsetMs;

  /// Server vaqtiga to'g'rilangan hozirgi lahza (qurilma zonasida).
  static DateTime now() =>
      DateTime.now().add(Duration(milliseconds: _offsetMs));

  /// Offset oxirgi e'lon qilingan qiymatdan [changeThreshold] dan ko'p
  /// siljiganda yangi qiymat (shu isolate'da).
  static Stream<int> get offsetChanges => _changes.stream;

  /// Saqlangan offsetni bir marta o'qiydi (isolate boshida chaqiring; idempotent).
  /// Xato bo'lsa keyingi chaqiruv qayta uriniladi. Hech qachon xato tashlamaydi.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(prefsKey);
      // Shu orada javoblardan o'rganilgan bo'lsa — yangisi ustun.
      if (stored != null && _samples.isEmpty) {
        _offsetMs = stored;
        _announcedMs = stored;
      }
    } on Object catch (e) {
      debugPrint('[clock] offset o\'qilmadi: ${e.runtimeType}');
      _loading = null;
    }
  }

  /// Bitta javob namunasi. [serverDate] — `Date` sarlavhasi (soniyagacha
  /// kesilgan), [roundTrip] — so'rov yuborilgandan javobgacha (monoton),
  /// [receivedAt] — javob kelgan paytdagi qurilma soati.
  static void recordSample({
    required DateTime serverDate,
    required Duration roundTrip,
    required DateTime receivedAt,
  }) {
    if (roundTrip.isNegative || roundTrip > maxRoundTrip) return;
    // Sarlavha soniyaning boshini bildiradi — o'rtasi +500 ms.
    final serverMs = serverDate.millisecondsSinceEpoch + 500;
    final localMs =
        receivedAt.millisecondsSinceEpoch - roundTrip.inMilliseconds ~/ 2;
    _samples.add(serverMs - localMs);
    if (_samples.length > windowSize) _samples.removeAt(0);
    _offsetMs = _median(_samples);
    if ((_offsetMs - _announcedMs).abs() > changeThreshold.inMilliseconds) {
      _announcedMs = _offsetMs;
      _changes.add(_offsetMs);
    }
  }

  /// Mediana. Juft sonda o'rtadagi ikki namunadan HOZIRGI offsetga yaqini
  /// (o'rtacha emas — hech qachon bo'lmagan qiymat chiqmasin; yangi qiymat
  /// faqat ko'pchilik bo'lganda qabul qilinadi).
  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    final low = sorted[mid - 1];
    final high = sorted[mid];
    return (low - _offsetMs).abs() <= (high - _offsetMs).abs() ? low : high;
  }

  @visibleForTesting
  static void resetForTest() {
    _offsetMs = 0;
    _announcedMs = 0;
    _samples.clear();
    _loading = null;
  }
}
