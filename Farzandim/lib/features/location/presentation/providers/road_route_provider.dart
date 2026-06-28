// Trekni KO'CHALARGA yopishtirilgan (road-snapped) yo'lга aylantiruvchi
// provider. Xom GPS nuqtalari to'g'ri chiziq bilan ulansa — yo'l binolar
// ustidan kesib o'tadi. OSRM (OpenStreetMap, bepul/kalitsiz) "foot" yo'nalish
// xizmati nuqtalar orasini ko'chalar bo'ylab to'ldiradi. Tarmoq/CORS xatosida
// xom trek (to'g'ri chiziq) qaytadi — ya'ni eng yomon holatda eski ko'rinish.

import 'package:dio/dio.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/presentation/providers/location_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Bugungi trek uchun ko'chalarga yopishtirilgan yo'l (polyline nuqtalari).
final roadRouteProvider = FutureProvider.autoDispose
    .family<List<LatLng>, LocationHistoryQuery>((ref, query) async {
      final track = await ref.watch(locationHistoryProvider(query).future);

      List<LatLng> raw() => [
        for (final p in track) LatLng(p.latitude, p.longitude),
      ];

      if (track.length < 2) return raw();

      // OSRM URL uzunligini cheklash uchun trekni tekis namunaga keltiramiz.
      final pts = _sample(track, 20);
      final coords = pts.map((p) => '${p.longitude},${p.latitude}').join(';');
      // FOSSGIS OSRM (OSM saytida ishlatiladi) — CORS bor.
      final url =
          'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
          '$coords?overview=full&geometries=geojson';

      try {
        final res = await Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        ).get<Map<String, dynamic>>(url);

        final routes = res.data?['routes'] as List?;
        if (routes == null || routes.isEmpty) return raw();
        final geometry = (routes.first as Map)['geometry'] as Map?;
        final line = geometry?['coordinates'] as List?;
        if (line == null || line.length < 2) return raw();

        // GeoJSON: [lng, lat] tartibida.
        return [
          for (final c in line)
            LatLng((c as List)[1] as double, c[0] as double),
        ];
      } catch (_) {
        // Tarmoq/CORS/parse xatosi — xom trekka qaytamiz.
        return raw();
      }
    });

/// Trekni `max` ta nuqtaga tekis kamaytiradi (boshi va oxiri saqlanadi).
List<ChildLocation> _sample(List<ChildLocation> track, int max) {
  if (track.length <= max) return track;
  final step = (track.length - 1) / (max - 1);
  return [
    for (var i = 0; i < max; i++)
      track[(i * step).round().clamp(0, track.length - 1)],
  ];
}
