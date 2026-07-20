// ─────────────────────────────────────────────────────────────────────
// roadRouteProvider — trekni ko'chalarga yopishtirilgan CHIZIQLARGA aylantiradi
// ─────────────────────────────────────────────────────────────────────
//
// MUHIM O'ZGARISH: avval butun kun BITTA chiziq edi va OSRM `/match` HAR DOIM
// chaqirilardi. Natijada:
//   • uyda o'tirganda GPS sochilishi ko'chaga "yopishib", bola ko'chada
//     yurgandek ko'rinardi (radius 50 m — 6-qavatdan ko'chagacha yetardi);
//   • uzilishlar (telefon o'chgan) to'g'ri chiziq bilan ulanardi;
//   • 6 km avtomobil safari PIYODA profili bilan hovlilardan o'tkazilardi.
//
// Endi:
//   1. Trek segmentlarga bo'linadi (TrackCleaner) — turgan joy alohida.
//   2. Map-matching FAQAT haqiqiy harakat segmentiga qo'llanadi (shartlar
//      qat'iy: nuqta soni, masofa, tezlik). Turgan joy hech qachon yo'lga
//      yopishtirilmaydi.
//   3. Tezlikka qarab profil: piyoda yoki mashina.
//   4. Har segment ALOHIDA chiziq — uzilishlar ulanmaydi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/services/track_cleaner.dart';
import 'package:farzandim/features/location/presentation/providers/location_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Ko'chalarga yopishtirilgan yo'l — HAR BO'LAK alohida chiziq.
///
/// Bo'sh ro'yxat = chizadigan harakat yo'q (masalan bola kun bo'yi uyda).
typedef RouteSegments = List<List<LatLng>>;

/// Berilgan oraliq uchun yo'l bo'laklari.
final roadRouteProvider = FutureProvider.autoDispose
    .family<RouteSegments, LocationHistoryQuery>((ref, query) async {
      final raw = await ref.watch(locationHistoryProvider(query).future);
      final cleaned = TrackCleaner.process(raw);
      final moves = cleaned.movements;
      if (moves.isEmpty) return const <List<LatLng>>[];

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final out = <List<LatLng>>[];
      for (final seg in moves) {
        final rawLine = [
          for (final p in seg.points) LatLng(p.latitude, p.longitude),
        ];
        if (rawLine.length < 2) continue;

        // Yo'lga yopishtirishga arzimasa — xom (tozalangan) chiziq.
        if (!_shouldMatch(seg)) {
          out.add(rawLine);
          continue;
        }

        final matched = await _match(dio, seg);
        if (matched == null || matched.isEmpty) {
          out.add(rawLine);
          continue;
        }
        out.addAll(matched);
      }
      return out;
    });

/// Segmentni yo'lga yopishtirish kerakmi?
///
/// Shovqin to'plamini (turgan joy qoldig'i, yakka sakrash) yo'lga
/// yopishtirish — aynan "uyda o'tirsam ko'chada yurgan qilib ko'rsatadi"
/// muammosining sababi. Shuning uchun shartlar qat'iy.
bool _shouldMatch(TrackSegment seg) {
  if (seg.isStay) return false;
  if (seg.points.length < 6) return false; // juda kam nuqta — ishonchsiz
  if (seg.spanMeters < 150) return false; // joyidan sezilarli ketmagan
  if (seg.pathMeters < 200) return false;
  final v = seg.medianSpeedMps;
  if (v < 0.5 || v > 40) return false; // turgan yoki imkonsiz tez
  if (seg.duration > const Duration(hours: 2)) return false;
  return true;
}

/// OSRM `/match` — bitta segmentni yo'l tarmog'iga moslaydi.
///
/// `gaps=split` — OSRM ulab bo'lmaydigan joyni O'ZI bo'lib beradi; biz
/// har bo'lakni ALOHIDA chiziq qilamiz (avval hammasi bitta ro'yxatga
/// qo'shilardi va OSRM chizishdan bosh tortgan joy to'g'ri chiziq bo'lardi).
Future<List<List<LatLng>>?> _match(Dio dio, TrackSegment seg) async {
  final pts = _sampleByDistance(seg.points, maxPoints: 100, minSpacingM: 20);
  if (pts.length < 6) return null;

  final coords = pts.map((p) => '${p.longitude},${p.latitude}').join(';');
  final radiuses = pts.map((p) => _radius(p.accuracy)).join(';');
  // Tezlikka qarab profil — 2.5 m/s (~9 km/soat) dan tez bo'lsa transport.
  final profile = seg.medianSpeedMps >= 2.5
      ? 'routed-car/car'
      : 'routed-foot/foot';

  final url =
      'https://routing.openstreetmap.de/$profile/match/v1/'
      '${profile.split('/').last}/$coords'
      '?geometries=geojson&overview=full&tidy=true&gaps=split'
      '&radiuses=$radiuses';

  try {
    final res = await dio.get<Map<String, dynamic>>(url);
    final matchings = res.data?['matchings'] as List?;
    if (matchings == null || matchings.isEmpty) return null;

    final lines = <List<LatLng>>[];
    for (final m in matchings) {
      final map = m as Map;
      // Ishonch past bo'lsa — bu taxmin, chizmaymiz.
      final conf = (map['confidence'] as num?)?.toDouble() ?? 0;
      if (conf < 0.3) continue;
      final coordsList = (map['geometry'] as Map?)?['coordinates'] as List?;
      if (coordsList == null || coordsList.length < 2) continue;
      lines.add([
        for (final c in coordsList)
          LatLng((c as List)[1] as double, c[0] as double),
      ]);
    }
    if (lines.isEmpty) return null;

    // Xavfsizlik: moslashtirilgan yo'l xom yo'ldan 2.5 barobar uzun bo'lsa,
    // OSRM adashgan (hovli/aylanma qo'shgan) — xom chiziqni afzal ko'ramiz.
    final matchedLen = lines.fold<double>(0, (a, l) => a + _lineMeters(l));
    if (matchedLen > seg.pathMeters * 2.5 + 200) return null;

    return lines;
  } catch (_) {
    return null;
  }
}

/// OSRM qidiruv radiusi (metr). 50 m juda keng edi — binodagi nuqta
/// ko'chagacha yetib, ko'chaga yopishardi. Endi eng ko'pi 25 m.
double _radius(double accuracy) {
  if (accuracy <= 0) return 15;
  return accuracy.clamp(4, 25);
}

/// Masofa bo'yicha siyraklashtirish — indeks bo'yicha emas.
///
/// Indeks bo'yicha namuna olish uy blobiga OSRM byudjetining katta qismini
/// berardi; masofa bo'yicha olish esa yo'lni tekis qoplaydi.
List<ChildLocation> _sampleByDistance(
  List<ChildLocation> pts, {
  required int maxPoints,
  required double minSpacingM,
}) {
  if (pts.length <= 2) return pts;
  final out = <ChildLocation>[pts.first];
  for (var i = 1; i < pts.length - 1; i++) {
    if (_distM(out.last, pts[i]) >= minSpacingM) out.add(pts[i]);
  }
  out.add(pts.last);
  if (out.length <= maxPoints) return out;
  // Hali ko'p bo'lsa — tekis kamaytiramiz (boshi/oxiri saqlanadi).
  final step = (out.length - 1) / (maxPoints - 1);
  return [
    for (var i = 0; i < maxPoints; i++)
      out[(i * step).round().clamp(0, out.length - 1)],
  ];
}

double _lineMeters(List<LatLng> line) {
  const d = Distance();
  var sum = 0.0;
  for (var i = 1; i < line.length; i++) {
    sum += d.as(LengthUnit.Meter, line[i - 1], line[i]);
  }
  return sum;
}

double _distM(ChildLocation a, ChildLocation b) {
  const d = Distance();
  return d.as(
    LengthUnit.Meter,
    LatLng(a.latitude, a.longitude),
    LatLng(b.latitude, b.longitude),
  );
}
