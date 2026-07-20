// ─────────────────────────────────────────────────────────────────────
// TrackCleaner — xom GPS trekni tozalaydi (yurgan yo'l aniq ko'rinsin).
// ─────────────────────────────────────────────────────────────────────
//
// GPS uch xil "shovqin" beradi, ular yurgan yo'lni buzadi:
//  1) YOMON ANIQLIK — uy/cafe ichida (ayniqsa balandда, multipath: signal
//     binolardan qaytadi) accuracy 30–60m bo'ladi va nuqta ko'chaga "sochiladi"
//     (aslida chiqmagan bo'lsangiz ham ko'chada ko'rinasiz). Yechim: accuracy
//     yomon nuqtalarni tashlaymiz.
//  2) MAYDA JITTER — bir joyda turганда nuqta 5–10m tebranadi. Yechim: oldingi
//     saqlanган nuqtaдан juda yaqin (minMove'дан kam) nuqtalarni yutamiz.
//  3) SPIKE — bitta nuqta chetga otilib qaytadi (A→B→A). Yechim: shundayni
//     olib tashlaymiz.
//
// Bu FAQAT tozalash (yo'lга yopishtirish emas) — road-matching keyin OSRM
// `/match` bilan `road_route_provider`да bo'ladi.

import 'dart:math' as math;

import 'package:farzandim/features/location/data/models/child_location.dart';

/// Xom trekni tozalovchi yordamchi.
class TrackCleaner {
  TrackCleaner._();

  /// [points] (ASC, eski→yangi) trekni tozalab qaytaradi.
  ///
  /// - [maxAccuracyM]: bundan yomon aniqlikdagi nuqtalar tashlanadi (indoor
  ///   multipath sochilishi). `accuracy == 0` = noma'lum → o'tkaziladi.
  /// - [minMoveM]: oldingi saqlanган nuqtaдан shundan kam siljigan nuqta
  ///   yutiladi (statsionar jitter).
  static List<ChildLocation> clean(
    List<ChildLocation> points, {
    double maxAccuracyM = 35,
    double minMoveM = 12,
    double maxSpeedKmh = 130,
  }) {
    if (points.length < 2) return points;

    // 1) Aniqlik filtri — yomon (sochiluvchan) nuqtalarni tashlaymiz.
    final accurate = <ChildLocation>[
      for (final p in points)
        if (p.accuracy <= 0 || p.accuracy <= maxAccuracyM) p,
    ];
    if (accurate.length < 2) return accurate;

    // 1b) TELEPORT — GPS ba'zan uyali tarmoq (cell tower) bo'yicha o'nlab/yuzlab
    //     km narida nuqta beradi. Bunday nuqta yo'lga yopishtirilsa, xaritada
    //     MAGISTRAL bo'ylab uzun soxta chiziq chiziladi (bola u yerga bormagan).
    //     Shuning uchun jismonan imkonsiz tezlikdagi nuqtani tashlaymiz.
    final grounded = _dropTeleports(accurate, maxSpeedKmh);
    if (grounded.length < 2) return grounded;

    // 2) Statsionar jitter — oxirgi SAQLANGAN nuqtaдан minMove'дан kam
    //    siljiganlarni yutamiz. Oxirgi nuqta (hozirgi joy) har doim qoladi.
    final kept = <ChildLocation>[grounded.first];
    for (var i = 1; i < grounded.length; i++) {
      if (_distM(kept.last, grounded[i]) >= minMoveM) kept.add(grounded[i]);
    }
    if (!identical(kept.last, grounded.last)) kept.add(grounded.last);
    if (kept.length < 3) return kept;

    // 3) Spike (A→B→A) — o'rtadagi nuqta chetга otilib qaytган bo'lsa tashlash.
    final smooth = <ChildLocation>[kept.first];
    for (var i = 1; i < kept.length - 1; i++) {
      final out = _distM(smooth.last, kept[i]);
      final back = _distM(smooth.last, kept[i + 1]);
      final isSpike = out > 40 && back < 15;
      if (!isSpike) smooth.add(kept[i]);
    }
    smooth.add(kept.last);
    return smooth;
  }

  /// Jismonan imkonsiz tezlikdagi ("teleport") nuqtalarni tashlaydi.
  ///
  /// Har nuqta OXIRGI SAQLANGAN yaxshi nuqta bilan solishtiriladi — shunda
  /// bitta yomon nuqta o'zidan keyingi to'g'ri nuqtalarni "sudrab" ketmaydi
  /// (yomon nuqta tashlanadi, iz davom etaveradi).
  ///
  /// `maxKmh` — avtomobil/avtobus sig'adigan chegara (130 km/soat). Undan
  /// yuqorisi GPS xatosi: masalan 1 daqiqada 100 km = 6000 km/soat.
  static List<ChildLocation> _dropTeleports(
    List<ChildLocation> pts,
    double maxKmh,
  ) {
    if (pts.length < 2) return pts;
    final out = <ChildLocation>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      final prev = out.last;
      final cur = pts[i];
      final meters = _distM(prev, cur);
      final secs = cur.updatedAt.difference(prev.updatedAt).inSeconds;
      if (secs <= 0) {
        // Vaqt bir xil yoki teskari (buzuq yozuv) — tezlikni hisoblab
        // bo'lmaydi. Faqat aniq bema'ni sakrashni (>1 km) tashlaymiz.
        if (meters > 1000) continue;
        out.add(cur);
        continue;
      }
      final kmh = meters / secs * 3.6;
      if (kmh > maxKmh) continue; // teleport — tashlaymiz
      out.add(cur);
    }
    return out;
  }

  /// Ikki nuqta orasidagi masofa (metr) — haversine.
  static double _distM(ChildLocation a, ChildLocation b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
