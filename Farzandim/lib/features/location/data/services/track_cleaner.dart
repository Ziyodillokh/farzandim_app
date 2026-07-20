// ─────────────────────────────────────────────────────────────────────
// TrackCleaner — xom GPS trekni tozalab, SEGMENTLARGA ajratadi.
// ─────────────────────────────────────────────────────────────────────
//
// MUAMMO (foydalanuvchi shikoyati):
//   • "Uyimda 6-qavatda yursam ham ko'chada yurgan qilib ko'rsatyapti"
//   • "6 km yurdim, lekin juda keraksiz chiziqlar ham chizdi"
//
// SABAB: bola ilovasi har 60 soniyada joylashuv yuboradi (harakatsiz bo'lsa
// ham), binoda GPS 25–60 m "sochiladi" (multipath — signal devorlardan
// qaytadi). Natijada bir joyda o'tirgan bola soatiga ~30 ta tarqoq nuqta
// beradi. Eski tozalagich bularni "yurish" deb qabul qilardi (chunki har
// qadam 12 m dan katta), keyin OSRM ularni KO'CHAGA yopishtirib, orasini
// ko'cha bo'ylab chizardi.
//
// YECHIM — 5 bosqich:
//   1) ANIQLIK darvozasi — yomon (sochiluvchan) nuqtalar tashlanadi.
//   2) TELEPORT — imkonsiz tezlikdagi sakrashlar olib tashlanadi/kesiladi.
//   3) TURGAN JOY (stay-point) — bir joyda uzoq turilgan nuqtalar TO'PLAMI
//      BITTA nuqtaga yig'iladi. Bu asosiy tuzatish: uy blobi yo'qoladi.
//   4) SEGMENT — vaqt uzilishi/turgan joy/teleport bo'yicha trek bo'laklarga
//      bo'linadi. Har bo'lak ALOHIDA chiziq → uzilishlar ulanmaydi
//      ("keraksiz chiziqlar" yo'qoladi).
//   5) JITTER — segment ichida juda yaqin nuqtalar siyraklashtiriladi.
//
// Masofa FAQAT harakat segmentlaridan hisoblanadi — uyda turgan "arvoh km"
// qo'shilmaydi.
//
// Bu tozalash; yo'lga yopishtirish (map-matching) `road_route_provider`da.

import 'dart:math' as math;

import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:flutter/foundation.dart';

/// Trek bo'lagi — yo HARAKAT (yurilgan qism), yo TURGAN JOY (stay).
@immutable
class TrackSegment {
  const TrackSegment({required this.points, required this.isStay});

  /// Bo'lakdagi nuqtalar (vaqt bo'yicha o'sish tartibida).
  final List<ChildLocation> points;

  /// `true` — bir joyda turilgan (uy/maktab/do'kon); chiziq chizilmaydi.
  final bool isStay;

  DateTime get from => points.first.updatedAt;
  DateTime get to => points.last.updatedAt;
  Duration get duration => to.difference(from);

  /// Turgan joy uchun VAKIL nuqta — markazga eng yaqin haqiqiy nuqta
  /// (medoid). Shu bitta nuqta xaritada ko'rsatiladi.
  ChildLocation get center {
    if (points.length == 1) return points.first;
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    final mLat = sumLat / points.length;
    final mLng = sumLng / points.length;
    var best = points.first;
    var bestD = double.infinity;
    for (final p in points) {
      final d = _rawDist(p.latitude, p.longitude, mLat, mLng);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  /// Bo'lak bo'ylab yurilgan masofa (ketma-ket nuqtalar yig'indisi), metr.
  double get pathMeters {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += _dist(points[i - 1], points[i]);
    }
    return sum;
  }

  /// Boshidan oxirigacha to'g'ri chiziq masofasi, metr.
  double get spanMeters =>
      points.length < 2 ? 0 : _dist(points.first, points.last);

  /// Median tezlik (m/s) — profil tanlash uchun (piyoda/mashina).
  /// Nuqtalar orasidagi masofa/vaqtdan hisoblanadi.
  double get medianSpeedMps {
    if (points.length < 2) return 0;
    final speeds = <double>[];
    for (var i = 1; i < points.length; i++) {
      final dt = points[i].updatedAt
          .difference(points[i - 1].updatedAt)
          .inMilliseconds;
      if (dt <= 0) continue;
      speeds.add(_dist(points[i - 1], points[i]) / (dt / 1000));
    }
    if (speeds.isEmpty) return 0;
    speeds.sort();
    return speeds[speeds.length ~/ 2];
  }
}

/// Tozalangan trek — segmentlar + haqiqiy harakat masofasi.
@immutable
class CleanedTrack {
  const CleanedTrack(this.segments);

  /// Bo'sh trek.
  static const empty = CleanedTrack(<TrackSegment>[]);

  final List<TrackSegment> segments;

  /// Faqat harakat bo'laklari (chiziq chiziladiganlar).
  List<TrackSegment> get movements => [
    for (final s in segments)
      if (!s.isStay) s,
  ];

  /// Turgan joylar (marker sifatida ko'rsatiladi).
  List<TrackSegment> get stays => [
    for (final s in segments)
      if (s.isStay) s,
  ];

  /// HAQIQIY yurilgan masofa (metr) — turgan joylar kirmaydi.
  ///
  /// Eski hisob butun tozalangan ro'yxat bo'ylab yig'ardi: uyda 8 soat
  /// o'tirish ~8 km "arvoh masofa" qo'shardi.
  double get movementMeters {
    var sum = 0.0;
    for (final s in movements) {
      sum += s.pathMeters;
    }
    return sum;
  }

  /// Marker/fallback uchun tekis ro'yxat: harakat nuqtalari + turgan
  /// joylarning vakil nuqtasi (vaqt tartibida).
  List<ChildLocation> get displayPoints {
    final out = <ChildLocation>[];
    for (final s in segments) {
      if (s.isStay) {
        out.add(s.center);
      } else {
        out.addAll(s.points);
      }
    }
    return out;
  }
}

/// Xom trekni tozalovchi.
class TrackCleaner {
  TrackCleaner._();

  /// Chizish uchun ruxsat etilgan eng yomon aniqlik (metr).
  /// 35 m juda yumshoq edi — binodagi multipath fixlar o'tib ketardi.
  static const double kMaxAccuracyM = 25;

  /// Aniqlik yomon bo'lsa ham ishlatiladigan zaxira chegara (nuqta kam qolsa).
  static const double kRelaxedAccuracyM = 40;

  /// Turgan joy radiusi (metr) — shu doira ichidagi nuqtalar "bir joy".
  static const double kStayRadiusM = 60;

  /// Turgan joy uchun minimal vaqt — shundan uzoq turilsa "stay".
  static const Duration kStayMinDuration = Duration(minutes: 5);

  /// Ikki turgan joy shu vaqtdan kam ajralsa — birlashtiriladi.
  static const Duration kStayMergeGap = Duration(minutes: 3);

  /// Vaqt uzilishi — shundan katta bo'lsa trek BO'LINADI (chiziq ulanmaydi).
  static const Duration kMaxGap = Duration(minutes: 5);

  /// Imkonsiz tezlik (m/s) — 40 m/s ≈ 144 km/soat.
  static const double kMaxSpeedMps = 40;

  /// Segment ichidagi jitterni siyraklashtirish (metr).
  static const double kMinMoveM = 12;

  /// Xom trekni tozalab, segmentlarga ajratadi.
  ///
  /// [points] — istalgan tartibda bo'lishi mumkin (offline flush aralashtirib
  /// yuborishi mumkin); ichida vaqt bo'yicha saralanadi.
  static CleanedTrack process(List<ChildLocation> points) {
    if (points.isEmpty) return CleanedTrack.empty;

    // 0) Tozalash + VAQT BO'YICHA SARALASH. Offline buffer eski nuqtalarni
    //    keyin yuborishi mumkin — saralamasak chiziq oldinga-orqaga sakraydi.
    final sane = <ChildLocation>[
      for (final p in points)
        if (_isSane(p)) p,
    ]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    if (sane.length < 2) {
      return CleanedTrack([
        if (sane.isNotEmpty) TrackSegment(points: sane, isStay: true),
      ]);
    }

    // 1) ANIQLIK darvozasi. Noma'lum (<=0) aniqlik — ishonchsiz, tashlanadi
    //    (eski kod uni o'tkazib yuborardi → filtr umuman ishlamasdi).
    var accurate = _byAccuracy(sane, kMaxAccuracyM);
    if (accurate.length < 2) {
      // Kun siyrak bo'lsa (kam nuqta) — yumshoqroq chegara bilan qayta.
      accurate = _byAccuracy(sane, kRelaxedAccuracyM, allowUnknown: true);
    }
    if (accurate.length < 2) {
      return CleanedTrack([
        if (accurate.isNotEmpty) TrackSegment(points: accurate, isStay: true),
      ]);
    }

    // 2) TELEPORT — imkonsiz tezlikdagi yakka nuqtani olib tashlaymiz.
    final noJump = _dropTeleports(accurate);

    // 3) TURGAN JOY + 4) SEGMENT — birgalikda.
    final segments = _segment(noJump);

    return CleanedTrack(segments);
  }

  /// Eski API (moslik uchun) — tekis ro'yxat qaytaradi.
  ///
  /// Marker/fallback chiziq uchun. Yangi kod `process()` ni ishlatsin.
  static List<ChildLocation> clean(
    List<ChildLocation> points, {
    double? maxAccuracyM,
    double? minMoveM,
  }) => process(points).displayPoints;

  // ── Bosqichlar ──────────────────────────────────────────────────────

  /// Buzuq yozuvlarni chiqarib tashlaydi (sana yo'q / (0,0) koordinata).
  static bool _isSane(ChildLocation p) {
    if (p.updatedAt.year < 2000) return false; // parse bo'lmagan sana
    if (p.latitude == 0 && p.longitude == 0) return false;
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) return false;
    return true;
  }

  static List<ChildLocation> _byAccuracy(
    List<ChildLocation> pts,
    double maxM, {
    bool allowUnknown = false,
  }) => [
    for (final p in pts)
      if (p.accuracy > 0 ? p.accuracy <= maxM : allowUnknown) p,
  ];

  /// Imkonsiz sakrashlarni olib tashlaydi (A→uzoq→A qaytish).
  static List<ChildLocation> _dropTeleports(List<ChildLocation> pts) {
    if (pts.length < 3) return pts;
    final out = <ChildLocation>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final prev = out.last;
      final cur = pts[i];
      final next = pts[i + 1];
      final dtIn = cur.updatedAt.difference(prev.updatedAt).inMilliseconds;
      if (dtIn <= 0) continue; // dublikat vaqt
      final vIn = _dist(prev, cur) / (dtIn / 1000);
      // Tezlik imkonsiz VA keyingi nuqta oldingisiga qaytgan → yakka spike.
      if (vIn > kMaxSpeedMps && _dist(prev, next) < _dist(prev, cur) / 2) {
        continue; // cur tashlanadi
      }
      out.add(cur);
    }
    out.add(pts.last);
    return out;
  }

  /// Turgan joylarni aniqlab, trekni segmentlarga ajratadi.
  static List<TrackSegment> _segment(List<ChildLocation> pts) {
    final segments = <TrackSegment>[];
    var move = <ChildLocation>[]; // joriy harakat bo'lagi

    void flushMove() {
      if (move.isEmpty) return;
      final thinned = _thin(move);
      // Juda kichik bo'lakni tashlaymiz (yakka shovqin), lekin
      // 2+ nuqtali va sezilarli bo'lakni saqlaymiz.
      final span = thinned.length < 2
          ? 0.0
          : _dist(thinned.first, thinned.last);
      if (thinned.length >= 3 || span >= 100) {
        segments.add(TrackSegment(points: thinned, isStay: false));
      }
      move = <ChildLocation>[];
    }

    var i = 0;
    while (i < pts.length) {
      // Shu nuqtadan turgan joy bormi? (radius ichida qancha cho'ziladi)
      var j = i + 1;
      while (j < pts.length && _dist(pts[i], pts[j]) <= kStayRadiusM) {
        j++;
      }
      final cluster = pts.sublist(i, j);
      final stayed =
          cluster.length >= 2 &&
          cluster.last.updatedAt.difference(cluster.first.updatedAt) >=
              kStayMinDuration;

      if (stayed) {
        // Turgan joy — oldingi harakatni yopamiz, stay qo'shamiz.
        flushMove();
        segments.add(TrackSegment(points: cluster, isStay: true));
        i = j;
        continue;
      }

      // Harakat nuqtasi. Oldingisidan uzilish bormi?
      if (move.isNotEmpty) {
        final prev = move.last;
        final gap = pts[i].updatedAt.difference(prev.updatedAt);
        final sameDay = _sameDay(pts[i].updatedAt, prev.updatedAt);
        // Imkonsiz tezlikdagi sakrash QAYTMASA — `_dropTeleports` uni
        // tashlamaydi (u faqat "chetga otilib qaytgan"ni oladi). Bunday
        // sakrashni ULAB qo'ysak, xaritada uzun soxta chiziq chiqadi —
        // shuning uchun bu ham UZILISH deb qaraladi.
        final secs = gap.inMilliseconds / 1000;
        final tooFast = secs > 0 && _dist(prev, pts[i]) / secs > kMaxSpeedMps;
        if (gap > kMaxGap || !sameDay || tooFast) {
          flushMove(); // uzilish → yangi bo'lak (chiziq ulanmaydi)
        }
      }
      move.add(pts[i]);
      i++;
    }
    flushMove();

    return _mergeNearbyStays(segments);
  }

  /// Yaqin va qisqa vaqt ajralgan turgan joylarni birlashtiradi (drift
  /// doiradan qisqa chiqib qaytsa, ikkita "stay" bo'lib ketmasin).
  static List<TrackSegment> _mergeNearbyStays(List<TrackSegment> segs) {
    if (segs.length < 2) return segs;
    final out = <TrackSegment>[];
    for (final s in segs) {
      if (out.isEmpty) {
        out.add(s);
        continue;
      }
      final prev = out.last;
      final canMerge =
          prev.isStay &&
          s.isStay &&
          s.from.difference(prev.to) <= kStayMergeGap &&
          _dist(prev.center, s.center) <= kStayRadiusM * 2;
      if (canMerge) {
        out[out.length - 1] = TrackSegment(
          points: [...prev.points, ...s.points],
          isStay: true,
        );
      } else {
        out.add(s);
      }
    }
    return out;
  }

  /// Segment ichidagi mayda jitterni siyraklashtiradi.
  static List<ChildLocation> _thin(List<ChildLocation> pts) {
    if (pts.length < 3) return pts;
    final kept = <ChildLocation>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      if (_dist(kept.last, pts[i]) >= kMinMoveM) kept.add(pts[i]);
    }
    kept.add(pts.last);
    return kept;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Ikki nuqta orasidagi masofa (metr) — haversine.
double _dist(ChildLocation a, ChildLocation b) =>
    _rawDist(a.latitude, a.longitude, b.latitude, b.longitude);

double _rawDist(double aLat, double aLng, double bLat, double bLng) {
  const r = 6371000.0;
  final dLat = _rad(bLat - aLat);
  final dLng = _rad(bLng - aLng);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(aLat)) *
          math.cos(_rad(bLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180;
