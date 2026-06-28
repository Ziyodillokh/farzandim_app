// Harakat tarixi provider'lari. Tarix real-time emas (yangi nuqta
// childLocationProvider orqali keladi), shuning uchun FutureProvider.

import 'dart:math' as math;

import 'package:farzandim/core/utils/polling.dart' show keepAliveFor;
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:farzandim/features/location/data/services/geocoding_service.dart';
import 'package:farzandim/features/location/presentation/providers/location_mock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `locationHistoryProvider.family` argumenti — `(childId, fromMs, toMs)`
/// record. Vaqt epoch ms sifatida: int'lar bilan record equality
/// barqaror, family keshi to'g'ri ishlaydi.
typedef LocationHistoryQuery = ({String childId, int fromMs, int toMs});

/// Bola harakat tarixini Backend'dan oladi.
final locationHistoryProvider = FutureProvider.autoDispose
    .family<List<ChildLocation>, LocationHistoryQuery>((ref, query) async {
      if (kLocationMock) return mockTrack(); // MOCK (UI preview)
      final auth = ref.watch(backendAuthProvider);
      if (auth is! AuthAuthenticated) return const [];
      // autoDispose + qisqa kesh — aks holda har sana-oralig'i kaliti
      // abadiy keshda qolib xotira cheksiz o'sadi.
      keepAliveFor(ref, const Duration(minutes: 2));

      final repo = ref.watch(backendLocationRepositoryProvider);
      // To'liq kunni sahifalab olamiz: avval bitta 500 talik so'rov edi va
      // uzun kunda eng eski qism (safarning o'zi!) jimgina kesilib qolardi.
      // 6 sahifa x 500 = 3000 nuqta — kunlik trek uchun yetarli shift.
      final all = <ChildLocation>[];
      DateTime? before;
      for (var page = 0; page < 6; page++) {
        final batch = await repo.getHistory(
          childId: query.childId,
          from: DateTime.fromMillisecondsSinceEpoch(query.fromMs),
          to: DateTime.fromMillisecondsSinceEpoch(query.toMs),
          before: before,
          limit: 500,
        );
        all.addAll(batch);
        if (batch.length < 500) break;
        // DESC tartib — sahifaning oxirgisi eng eskisi, keyingi cursor.
        before = batch.last.updatedAt;
      }
      // Backend DESC qaytaradi — polyline uchun ASC qilamiz.
      return all.reversed.toList();
    });

/// Bola to'xtagan joylari (backend stop-detection) — xaritada marker.
/// Bir xil `LocationHistoryQuery` kaliti bilan (sana oralig'i).
final locationStopsProvider = FutureProvider.autoDispose
    .family<List<LocationStop>, LocationHistoryQuery>((ref, query) async {
      if (kLocationMock) return mockStops(); // MOCK (UI preview)
      final auth = ref.watch(backendAuthProvider);
      if (auth is! AuthAuthenticated) return const [];
      keepAliveFor(ref, const Duration(minutes: 2)); // qisqa kesh

      final repo = ref.watch(backendLocationRepositoryProvider);
      return repo.getStops(
        childId: query.childId,
        from: DateTime.fromMillisecondsSinceEpoch(query.fromMs),
        to: DateTime.fromMillisecondsSinceEpoch(query.toMs),
      );
    });

/// Trek bo'ylab KIRILGAN KO'CHALAR ro'yxati — taxminan har 250 metrda
/// bitta nuqta reverse-geocode qilinadi (OS geocoder birinchi, ichki kesh
/// bilan — arzon), ko'cha nomlari birinchi kirish tartibida yig'iladi.
/// Maksimal 30 ta sample — uzun kunda ham geocode xarajati chegaralangan.
final traversedStreetsProvider = FutureProvider.autoDispose
    .family<List<String>, LocationHistoryQuery>((ref, query) async {
      final track = await ref.watch(locationHistoryProvider(query).future);
      if (track.length < 2) return const [];
      keepAliveFor(ref, const Duration(minutes: 2));
      final geo = ref.watch(geocodingServiceProvider);

      const sampleGapM = 250.0;
      const maxSamples = 30;
      final samples = <ChildLocation>[track.first];
      var acc = 0.0;
      for (var i = 1; i < track.length; i++) {
        acc += _distanceM(track[i - 1], track[i]);
        if (acc >= sampleGapM) {
          samples.add(track[i]);
          acc = 0;
          if (samples.length >= maxSamples) break;
        }
      }
      if (samples.length == 1 && track.length > 1) samples.add(track.last);

      final streets = <String>[];
      for (final point in samples) {
        final addr = await geo.reverse(point.latitude, point.longitude);
        if (addr == null) continue;
        final street = addr.split(',').first.trim();
        if (street.isEmpty) continue;
        if (!streets.contains(street)) streets.add(street);
      }
      return streets;
    });

/// Ikki nuqta orasidagi masofa (metr) — haversine.
double _distanceM(ChildLocation a, ChildLocation b) {
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

double _rad(double deg) => deg * math.pi / 180;
