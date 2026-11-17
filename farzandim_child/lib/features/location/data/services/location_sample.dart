// ─────────────────────────────────────────────────────────────────────
// Joylashuv strategiyasining sonlari va nuqta turi (sof, platformasiz)
// ─────────────────────────────────────────────────────────────────────
//
// Mantiq: location_strategy.dart. Koordinatalar log matniga HECH QACHON
// kirmaydi: `describe`/`toString` faqat aniqlik va yoshni aytadi.

import 'package:flutter/foundation.dart';

import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart'
    show distanceMeters;

enum LocationMode { stationary, trip }

/// Strategiya sonlari — bitta joyda.
abstract final class LocationTuning {
  // ── Oqim sozlamalari ──
  static const int stationaryDistanceFilterM = 50;
  static const Duration stationaryInterval = Duration(minutes: 3);
  static const int tripDistanceFilterM = 20;
  static const Duration tripInterval = Duration(seconds: 20);

  // ── Rejim almashuvi ──
  static const double tripEnterDistanceM = 150;
  static const double tripEnterSpeedMps = 2.5;
  static const double tripMoveM = 25;
  static const Duration tripIdleExit = Duration(minutes: 5);
  static const Duration wakeTripHold = Duration(minutes: 2);

  /// Shundan yomon nuqta rejimni o'zgartirmaydi (uyali-tarmoq fix'lari).
  static const double modeMaxAccuracyM = 100;

  /// Siljish chegarasi ≥ shu koeffitsient × (ikki aniqlik yig'indisi):
  /// aniqlik — 68% radius, ikkitasi osongina qo'shiladi.
  static const double noiseFactor = 2;

  // ── Tick / wake ──
  /// Maktab hududi 20 daqiqadan eski nuqtani "bilmayman" deydi (fail-closed);
  /// 10 daqiqa + ~5 daqiqalik tick + kechikish < 20.
  static const Duration staleFixAge = Duration(minutes: 10);
  static const Duration tickFixTimeLimit = Duration(seconds: 15);
  static const Duration wakeFixTimeLimit = Duration(seconds: 20);

  /// Bir wake ikki yo'ldan (native + Dart) kelsa — bitta fix.
  static const Duration wakeCooldown = Duration(seconds: 30);

  // ── Tarix (POST /location) darvozalari — o'zgarmagan ──
  static const double maxHistoryAccuracyM = 50;
  static const double minSendMoveM = 25;
  static const Duration aliveGap = Duration(minutes: 15);

  // ── Maktab hududi nuqtasi (SchoolZoneStore.recordFix) ──
  static const Duration zoneRecordMinGap = Duration(seconds: 60);
  static const double zoneRecordMinMoveM = 25;

  /// Devor soati shundan ko'proq orqaga surilsa — vaqt tartibi qaytadan
  /// (aks holda yangi nuqtalar "eski" deb tashlanardi).
  static const Duration clockJumpTolerance = Duration(minutes: 2);
}

/// Rejimga mos oqim parametrlari (platforma sozlamasi — LocationPlatform).
@immutable
class StreamSpec {
  const StreamSpec._({
    required this.highAccuracy,
    required this.distanceFilterM,
    required this.interval,
  });

  /// Balanced (Wi-Fi/uyali) — GNSS'siz.
  static const stationary = StreamSpec._(
    highAccuracy: false,
    distanceFilterM: LocationTuning.stationaryDistanceFilterM,
    interval: LocationTuning.stationaryInterval,
  );

  static const trip = StreamSpec._(
    highAccuracy: true,
    distanceFilterM: LocationTuning.tripDistanceFilterM,
    interval: LocationTuning.tripInterval,
  );

  static StreamSpec of(LocationMode mode) =>
      mode == LocationMode.trip ? trip : stationary;

  final bool highAccuracy;
  final int distanceFilterM;
  final Duration interval;
}

/// Platformadan mustaqil joylashuv nuqtasi.
@immutable
class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.at,
    this.speedMps = 0,
    this.speedAccuracyMps = 0,
    this.headingDeg = 0,
    this.altitudeM = 0,
  });

  final double latitude;
  final double longitude;

  /// Gorizontal aniqlik (m, 68% radius); ≤0 — noma'lum.
  final double accuracyM;

  /// Nuqtaning O'Z vaqti (fix vaqti).
  final DateTime at;
  final double speedMps;

  /// ≤0 — noma'lum.
  final double speedAccuracyMps;
  final double headingDeg;
  final double altitudeM;

  double distanceTo(LocationSample other) =>
      distanceMeters(latitude, longitude, other.latitude, other.longitude);

  /// Tezlik ishonchli va safar chegarasidan yuqori.
  bool get isFast =>
      speedMps >= LocationTuning.tripEnterSpeedMps &&
      (speedAccuracyMps <= 0 || speedAccuracyMps < speedMps);

  /// Log uchun — KOORDINATASIZ.
  String describe(DateTime now) =>
      'aniqlik ${accuracyM.round()} m, ${ageLabel(now.difference(at))}';

  @override
  String toString() => 'LocationSample(aniqlik: ${accuracyM.round()} m)';
}

/// Tarixga (POST /location) yaroqli aniqlik.
bool isHistoryGrade(LocationSample s) =>
    s.accuracyM > 0 && s.accuracyM <= LocationTuning.maxHistoryAccuracyM;

/// "12 s oldin" / "3 daq oldin" — log uchun.
String ageLabel(Duration d) {
  if (d.isNegative) return 'hozir';
  if (d.inSeconds < 60) return '${d.inSeconds} s oldin';
  return '${d.inMinutes} daq oldin';
}
