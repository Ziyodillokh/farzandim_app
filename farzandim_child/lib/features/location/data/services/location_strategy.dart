// ─────────────────────────────────────────────────────────────────────
// Joylashuv strategiyasi — SOF mantiq (LocationService uni boshqaradi)
// ─────────────────────────────────────────────────────────────────────
//
// 1.0.20 gacha: doimiy GPS oqimi (HIGH, 5 s / 10 m) + har 60 s yangi GPS fix
// — GNSS sutkasiga 24 soat yoniq turardi (batareyaning eng katta iste'molchisi).
// Endi ikki rejim:
//   - STATSIONAR (standart): balanced — Wi-Fi/uyali tarmoq, GNSS'siz;
//     50 m siljishda, ko'pi bilan 3 daqiqada bir nuqta.
//   - SAFAR: GPS (HIGH), 20 m / 20 s. Langardan ≥150 m siljish yoki tezlik
//     ≥2.5 m/s bo'lsa yoqiladi; 5 daqiqa ≥25 m siljish bo'lmasa o'chadi.
//     Ota-ona xaritani ochsa (wake) — kamida 2 daqiqa.
// Shovqin himoyasi: aniqlik — 68% radius, shu sabab siljish chegarasi ikki
// nuqta aniqliklari yig'indisining 2 baravaridan kam emas; 100 m dan yomon
// nuqta rejimni o'zgartirmaydi (uyali-tarmoq "sakrashi" GPS'ni yoqmasin).
//
// Tick (~5 daqiqa): nuqta 10 daqiqadan eski bo'lsa — BITTA balanced fix.
// Maktab hududi 20 daqiqadan eski nuqtani "bilmayman" deydi (fail-closed);
// 10 daqiqa + 5 daqiqalik tick + kechikish < 20. 15 daqiqalik "tirikman"
// nuqtasi ham tick'da.
//
// Tarix darvozalari (o'zgarmagan): aniqlik ≤50 m; siljish ≥25 m yoki 15
// daqiqada bir marta. Maktab hududi nuqtasi (prefs commit + fsync) — 60 s'da
// bir marta yoki max(aniqlik, 25 m)dan ko'p siljiganda.
//
// Vaqt doim tashqaridan (`now`) — testlanadi. Koordinatalar log matniga HECH
// QACHON kirmaydi: `describe`/`toString` faqat aniqlik va yoshni aytadi.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:farzandim_child/features/app_restrictions/data/services/school_zone.dart'
    show kZoneMaxAccuracyM;
import 'package:farzandim_child/features/location/data/services/location_sample.dart';

export 'package:farzandim_child/features/location/data/services/location_sample.dart';

bool _modeGrade(LocationSample s) =>
    s.accuracyM > 0 && s.accuracyM <= LocationTuning.modeMaxAccuracyM;

bool _zoneGrade(LocationSample s) =>
    s.accuracyM > 0 && s.accuracyM <= kZoneMaxAccuracyM;

/// Ikki nuqta shovqini qoplay oladigan masofa.
double _noise(LocationSample a, LocationSample b) =>
    LocationTuning.noiseFactor * (a.accuracyM + b.accuracyM);

/// Rejim: statsionar yoki safar (GPS).
@immutable
class MotionState {
  const MotionState.stationary({this.anchor})
    : mode = LocationMode.stationary,
      latest = null,
      lastMoveAt = null,
      holdUntil = null;

  const MotionState.trip({
    this.anchor,
    this.latest,
    this.lastMoveAt,
    this.holdUntil,
  }) : mode = LocationMode.trip;

  final LocationMode mode;

  /// Statsionarda — siljish o'lchanadigan langar; safarda — oxirgi harakat
  /// nuqtasi (wake bilan kirilganda birinchi nuqtagacha null).
  final LocationSample? anchor;

  /// Safardagi eng so'nggi yaroqli nuqta (statsionarga qaytishda langar).
  final LocationSample? latest;

  /// Safarda oxirgi haqiqiy harakat vaqti.
  final DateTime? lastMoveAt;

  /// Wake: safar kamida shu vaqtgacha.
  final DateTime? holdUntil;

  /// Safardan chiqish vaqti (statsionarda — null).
  DateTime? get exitAt {
    if (mode != LocationMode.trip) return null;
    final idle = lastMoveAt?.add(LocationTuning.tripIdleExit);
    final hold = holdUntil;
    if (idle == null && hold == null) return _epoch;
    if (idle == null) return hold;
    if (hold == null) return idle;
    return idle.isAfter(hold) ? idle : hold;
  }

  MotionState onSample(LocationSample s, DateTime now) {
    if (!_modeGrade(s)) return this;
    return mode == LocationMode.trip
        ? _tripSample(s, now)
        : _stationarySample(s, now);
  }

  MotionState _stationarySample(LocationSample s, DateTime now) {
    final a = anchor;
    if (s.isFast) {
      return MotionState.trip(anchor: s, latest: s, lastMoveAt: now);
    }
    if (a == null) return MotionState.stationary(anchor: s);
    final d = s.distanceTo(a);
    if (d >= math.max(LocationTuning.tripEnterDistanceM, _noise(a, s))) {
      return MotionState.trip(anchor: s, latest: s, lastMoveAt: now);
    }
    // Aniqroq nuqta eski langar doirasida — langar aniqlashadi.
    if (s.accuracyM < a.accuracyM && d <= a.accuracyM) {
      return MotionState.stationary(anchor: s);
    }
    return this;
  }

  MotionState _tripSample(LocationSample s, DateTime now) {
    final a = anchor;
    final moved =
        s.isFast ||
        (a != null &&
            s.distanceTo(a) >=
                math.max(LocationTuning.tripMoveM, _noise(a, s)));
    return MotionState.trip(
      // Wake bilan kirilgan bo'lsa birinchi nuqta faqat langar bo'ladi.
      anchor: moved || a == null ? s : a,
      latest: s,
      lastMoveAt: moved ? now : lastMoveAt,
      holdUntil: holdUntil,
    );
  }

  /// Vaqt o'tdi: safar tugaganmi. Soat orqaga surilsa (bola vaqtni
  /// o'zgartirdi) saqlangan vaqtlar `now`ga tushiriladi — safar (GPS)
  /// abadiy yoniq qolmasin.
  MotionState onClock(DateTime now) {
    if (mode != LocationMode.trip) return this;
    final normalized = MotionState.trip(
      anchor: anchor,
      latest: latest,
      lastMoveAt: _notAfter(lastMoveAt, now),
      holdUntil: _notAfter(holdUntil, now.add(LocationTuning.wakeTripHold)),
    );
    if (now.isBefore(normalized.exitAt!)) return normalized;
    return MotionState.stationary(anchor: latest ?? anchor);
  }

  /// Wake: kamida [LocationTuning.wakeTripHold] safar (jonli xarita).
  MotionState hold(DateTime now) {
    final until = now.add(LocationTuning.wakeTripHold);
    if (mode != LocationMode.trip) return MotionState.trip(holdUntil: until);
    return MotionState.trip(
      anchor: anchor,
      latest: latest,
      lastMoveAt: lastMoveAt,
      holdUntil: _later(holdUntil, until),
    );
  }
}

/// Tarix darvozalari: aniqlik ≤50 m; siljish ≥25 m yoki 15 daqiqada bir
/// marta ("tirikman"). Wake (force) siljish darvozasini chetlab o'tadi.
@immutable
class SendGate {
  const SendGate({this.lastSent, this.lastSentAt});

  final LocationSample? lastSent;
  final DateTime? lastSentAt;

  bool allows(LocationSample s, DateTime now, {bool force = false}) {
    if (!isHistoryGrade(s)) return false;
    final last = lastSent;
    if (last == null) return true;
    if (!s.at.isAfter(last.at)) return false; // eski yoki takror
    if (force || aliveDue(now)) return true;
    return s.distanceTo(last) >= LocationTuning.minSendMoveM;
  }

  bool aliveDue(DateTime now) {
    final at = lastSentAt;
    if (at == null) return true;
    final since = now.difference(at);
    return since.isNegative || since >= LocationTuning.aliveGap;
  }

  /// "Tirikman" nuqtasi: vaqti kelgan bo'lsa — hali yuborilmagan eng yangi
  /// aniq nuqta (15 daqiqadan eski emas).
  LocationSample? aliveCandidate(LocationSample? good, DateTime now) {
    if (good == null || !aliveDue(now)) return null;
    final last = lastSent;
    if (last != null && !good.at.isAfter(last.at)) return null;
    if (now.difference(good.at) > LocationTuning.aliveGap) return null;
    return good;
  }

  SendGate sent(LocationSample s, DateTime now) =>
      SendGate(lastSent: s, lastSentAt: now);
}

/// `SchoolZoneStore.recordFix` har chaqiruvda prefs faylini to'liq commit
/// (fsync) qiladi — 60 s'da bir marta yoki sezilarli siljishda.
@immutable
class ZoneThrottle {
  const ZoneThrottle({this.last, this.lastAt});

  final LocationSample? last;
  final DateTime? lastAt;

  bool allows(LocationSample s, DateTime now) {
    final prev = last;
    final at = lastAt;
    if (prev == null || at == null) return true;
    if (!s.at.isAfter(prev.at)) return false; // eski yoki takror
    final elapsed = now.difference(at);
    if (elapsed.isNegative || elapsed >= LocationTuning.zoneRecordMinGap) {
      return true;
    }
    final moved = s.distanceTo(prev);
    if (moved > math.max(s.accuracyM, LocationTuning.zoneRecordMinMoveM)) {
      return true;
    }
    // Oldingi nuqta hudud qaroriga yaroqsiz edi, bunisi yaroqli.
    return !_zoneGrade(prev) && _zoneGrade(s);
  }

  ZoneThrottle recorded(LocationSample s, DateTime now) =>
      ZoneThrottle(last: s, lastAt: now);
}

/// Yangi nuqta bo'yicha qaror.
@immutable
class SampleOutcome {
  const SampleOutcome({
    required this.tracker,
    required this.recordZone,
    required this.send,
  });

  final LocationTracker tracker;

  /// `SchoolZoneStore.recordFix` chaqirilsin.
  final bool recordZone;

  /// POST /location.
  final bool send;
}

/// Tick bo'yicha qaror.
@immutable
class TickOutcome {
  const TickOutcome({
    required this.tracker,
    required this.requestFix,
    this.alive,
  });

  final LocationTracker tracker;

  /// Nuqta eskirgan — BITTA balanced fix kerak.
  final bool requestFix;

  /// "Tirikman" sifatida yuboriladigan nuqta (allaqachon yuborilgan deb
  /// belgilangan).
  final LocationSample? alive;
}

/// Butun holat — o'zgarmas; har qadam yangi nusxa qaytaradi.
@immutable
class LocationTracker {
  const LocationTracker({
    this.motion = const MotionState.stationary(),
    this.sendGate = const SendGate(),
    this.zoneThrottle = const ZoneThrottle(),
    this.lastSampleAt,
    this.lastFixAt,
    this.lastGood,
    this.lastReceivedAt,
  });

  final MotionState motion;
  final SendGate sendGate;
  final ZoneThrottle zoneThrottle;

  /// Eng yangi nuqtaning o'z vaqti (eski nuqtalar rejimni buzmasin).
  final DateTime? lastSampleAt;

  /// Yangilik o'lchovi: eng yangi nuqta vaqti (`now`dan keyin emas).
  final DateTime? lastFixAt;

  /// Eng yangi tarixga yaroqli (≤50 m) nuqta — "tirikman" uchun.
  final LocationSample? lastGood;

  /// Oxirgi nuqta qabul qilingan devor vaqti (soat orqaga surilishini
  /// aniqlash uchun).
  final DateTime? lastReceivedAt;

  LocationMode get mode => motion.mode;

  bool isStale(DateTime now) {
    final at = lastFixAt;
    return at == null || now.difference(at) >= LocationTuning.staleFixAge;
  }

  /// OS keshidagi nuqta (getLastKnownPosition) yangilik sifatida yaraydimi.
  bool isFreshCandidate(LocationSample s, DateTime now) {
    final newest = lastSampleAt;
    return now.difference(s.at) < LocationTuning.staleFixAge &&
        (newest == null || s.at.isAfter(newest));
  }

  SampleOutcome onSample(
    LocationSample s, {
    required DateTime now,
    bool force = false,
  }) => _rebasedIfClockWentBack(now)._accept(s, now, force);

  SampleOutcome _accept(LocationSample s, DateTime now, bool force) {
    final newest = lastSampleAt == null || !s.at.isBefore(lastSampleAt!);
    final recordZone = zoneThrottle.allows(s, now);
    final send = sendGate.allows(s, now, force: force);
    return SampleOutcome(
      tracker: LocationTracker(
        motion: newest ? motion.onSample(s, now) : motion,
        sendGate: send ? sendGate.sent(s, now) : sendGate,
        zoneThrottle: recordZone ? zoneThrottle.recorded(s, now) : zoneThrottle,
        lastSampleAt: newest ? s.at : lastSampleAt,
        lastFixAt: _later(lastFixAt, s.at.isAfter(now) ? now : s.at),
        lastGood: newest && isHistoryGrade(s) ? s : lastGood,
        lastReceivedAt: now,
      ),
      recordZone: recordZone,
      send: send,
    );
  }

  /// Devor soati orqaga surilgan (bola vaqtni o'zgartirdi): nuqtalar vaqti
  /// ham orqaga ketadi — eski tartib bilan hammasi "eski" deb tashlanib,
  /// tarix va maktab hududi soat yetib kelguncha to'xtab qolardi. Tartib
  /// qaytadan boshlanadi; joylar (langar, rejim) saqlanadi.
  LocationTracker _rebasedIfClockWentBack(DateTime now) {
    final received = lastReceivedAt;
    if (received == null ||
        !now.isBefore(received.subtract(LocationTuning.clockJumpTolerance))) {
      return this;
    }
    return LocationTracker(motion: motion.onClock(now));
  }

  /// Safardan chiqish taymeri.
  LocationTracker onClock(DateTime now) => _withMotion(motion.onClock(now));

  /// Wake: kamida 2 daqiqa safar (jonli xarita).
  LocationTracker holdTrip(DateTime now) => _withMotion(motion.hold(now));

  /// ~5 daqiqalik tick: safardan chiqish (taymer zaxirasi), "tirikman"
  /// nuqtasi va eskirgan bo'lsa bitta fix.
  TickOutcome onTick(DateTime now) {
    final alive = sendGate.aliveCandidate(lastGood, now);
    final next = LocationTracker(
      motion: motion.onClock(now),
      sendGate: alive == null ? sendGate : sendGate.sent(alive, now),
      zoneThrottle: zoneThrottle,
      lastSampleAt: lastSampleAt,
      lastFixAt: _notAfter(lastFixAt, now),
      lastGood: lastGood,
      lastReceivedAt: lastReceivedAt,
    );
    return TickOutcome(
      tracker: next,
      requestFix: next.isStale(now),
      alive: alive,
    );
  }

  /// Log uchun — KOORDINATASIZ.
  String describe(DateTime now) =>
      'rejim: ${mode.name}, oxirgi fix: ${_ageOf(lastFixAt, now)}, '
      'oxirgi yuborish: ${_ageOf(sendGate.lastSentAt, now)}';

  LocationTracker _withMotion(MotionState next) => LocationTracker(
    motion: next,
    sendGate: sendGate,
    zoneThrottle: zoneThrottle,
    lastSampleAt: lastSampleAt,
    lastFixAt: lastFixAt,
    lastGood: lastGood,
    lastReceivedAt: lastReceivedAt,
  );
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DateTime? _later(DateTime? a, DateTime b) => a == null || b.isAfter(a) ? b : a;

DateTime? _notAfter(DateTime? t, DateTime limit) =>
    t == null || !t.isAfter(limit) ? t : limit;

String _ageOf(DateTime? at, DateTime now) =>
    at == null ? "yo'q" : ageLabel(now.difference(at));
