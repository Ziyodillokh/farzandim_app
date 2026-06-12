// Harakat tarixi provider'lari. Tarix real-time emas (yangi nuqta
// childLocationProvider orqali keladi), shuning uchun FutureProvider.

import 'package:farzandim/core/utils/polling.dart' show keepAliveFor;
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `locationHistoryProvider.family` argumenti — `(childId, fromMs, toMs)`
/// record. Vaqt epoch ms sifatida: int'lar bilan record equality
/// barqaror, family keshi to'g'ri ishlaydi.
typedef LocationHistoryQuery = ({String childId, int fromMs, int toMs});

/// Bola harakat tarixini Backend'dan oladi.
final locationHistoryProvider = FutureProvider.autoDispose
    .family<List<ChildLocation>, LocationHistoryQuery>((ref, query) async {
      final auth = ref.watch(backendAuthProvider);
      if (auth is! AuthAuthenticated) return const [];
      // autoDispose + qisqa kesh — aks holda har sana-oralig'i kaliti
      // abadiy keshda qolib xotira cheksiz o'sadi.
      keepAliveFor(ref, const Duration(minutes: 2));

      final repo = ref.watch(backendLocationRepositoryProvider);
      final history = await repo.getHistory(
        childId: query.childId,
        from: DateTime.fromMillisecondsSinceEpoch(query.fromMs),
        to: DateTime.fromMillisecondsSinceEpoch(query.toMs),
        limit: 500,
      );
      // Backend DESC qaytaradi — polyline uchun ASC qilamiz.
      return history.reversed.toList();
    });

/// Bola to'xtagan joylari (backend stop-detection) — xaritada marker.
/// Bir xil `LocationHistoryQuery` kaliti bilan (sana oralig'i).
final locationStopsProvider = FutureProvider.autoDispose
    .family<List<LocationStop>, LocationHistoryQuery>((ref, query) async {
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
