// Trekni KO'CHALARGA ANIQ yopishtirilган (road-matched) yo'lга aylantiruvchi
// provider. Ikki bosqich:
//  1) TOZALASH (TrackCleaner) — indoor sochilishi + jitter + spike olib
//     tashlanadi (uy/cafe ичida ko'chага "chiqib qolish" kamayadi).
//  2) MAP-MATCHING — OSRM `/match` GPS izini yo'lга aniq yopishtiradi. Bu
//     `/route`дан farqli: /route eng qisqa yo'lni topadi (haydашда egri →
//     burilганда to'g'rilanadi), /match esa AYNAN yurgan yo'lni yo'l tarmog'iga
//     moslaydi (radiuses = aniqlik, tidy = shovqinni tozalash).
// Fallback: /match bo'lmasa /route, u ham bo'lmasa tozalанган xom trek.

import 'package:dio/dio.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/services/track_cleaner.dart';
import 'package:farzandim/features/location/presentation/providers/location_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Berilган oraliq uchun ko'chalarga yopishtirilган yo'l (polyline nuqtalari).
final roadRouteProvider = FutureProvider.autoDispose
    .family<List<LatLng>, LocationHistoryQuery>((ref, query) async {
      final rawTrack = await ref.watch(locationHistoryProvider(query).future);
      // Avval tozalash — sochilish/jitter yo'lni buzmasin (matching'дан oldin
      // MUHIM: yomon nuqtalar yo'lга yopishса ko'chага chiqib ketardi).
      final track = TrackCleaner.clean(rawTrack);

      List<LatLng> cleanedLine() => [
        for (final p in track) LatLng(p.latitude, p.longitude),
      ];

      if (track.length < 2) return cleanedLine();

      // OSRM cheklovi ~100 nuqta — tekis namunaga keltiramiz.
      final pts = _sample(track, 100);
      final coords = pts.map((p) => '${p.longitude},${p.latitude}').join(';');
      final radiuses = pts.map((p) => _radius(p.accuracy)).join(';');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      // 1) Map-matching (aniq yopishtirish).
      final matched = await _tryMatch(dio, coords, radiuses);
      if (matched != null && matched.length >= 2) return matched;

      // 2) Fallback: eski /route usuli.
      final routed = await _tryRoute(dio, coords);
      if (routed != null && routed.length >= 2) return routed;

      // 3) Eng yomon holat — tozalанган xom trek (to'g'ri chiziq).
      return cleanedLine();
    });

/// OSRM `/match` — GPS izini yo'l tarmog'iga moslaydi.
Future<List<LatLng>?> _tryMatch(
  Dio dio,
  String coords,
  String radiuses,
) async {
  final url =
      'https://routing.openstreetmap.de/routed-foot/match/v1/foot/'
      '$coords?geometries=geojson&overview=full&tidy=true&radiuses=$radiuses';
  try {
    final res = await dio.get<Map<String, dynamic>>(url);
    final matchings = res.data?['matchings'] as List?;
    if (matchings == null || matchings.isEmpty) return null;
    // Bir necha matching bo'lsa (iz bo'linса) tartib bilan ulaymiz.
    final out = <LatLng>[];
    for (final m in matchings) {
      final line =
          ((m as Map)['geometry'] as Map?)?['coordinates'] as List?;
      if (line == null) continue;
      for (final c in line) {
        out.add(LatLng((c as List)[1] as double, c[0] as double));
      }
    }
    return out.length >= 2 ? out : null;
  } catch (_) {
    return null;
  }
}

/// OSRM `/route` — nuqtalar orasini ko'chalar bo'ylab to'ldiradi (fallback).
Future<List<LatLng>?> _tryRoute(Dio dio, String coords) async {
  final url =
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
      '$coords?overview=full&geometries=geojson';
  try {
    final res = await dio.get<Map<String, dynamic>>(url);
    final routes = res.data?['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final line =
        ((routes.first as Map)['geometry'] as Map?)?['coordinates'] as List?;
    if (line == null || line.length < 2) return null;
    return [
      for (final c in line) LatLng((c as List)[1] as double, c[0] as double),
    ];
  } catch (_) {
    return null;
  }
}

/// OSRM qidiruv radiusi (metr) — aniqlik yomon bo'lsa kengroq, lekin 4–50m
/// oralig'ida (juda keng radius noto'g'ri yo'lга yopishtirib yuboradi).
double _radius(double accuracy) {
  if (accuracy <= 0) return 15;
  return accuracy.clamp(4, 50);
}

/// Trekni `max` ta nuqtaga tekis kamaytiradi (boshi va oxiri saqlanadi).
List<ChildLocation> _sample(List<ChildLocation> track, int max) {
  if (track.length <= max) return track;
  final step = (track.length - 1) / (max - 1);
  return [
    for (var i = 0; i < max; i++)
      track[(i * step).round().clamp(0, track.length - 1)],
  ];
}
