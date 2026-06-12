// Sprint 4.4.2: Firestore stream → Backend REST
// Sprint 4.4.30: range Duration → custom DateTimeRange (from/to).
//
// History past data — real-time'sizdir (yangi point WS bilan kelganda
// `childLocationProvider` yangilanadi, history alohida polling/refresh).
// Demak StreamProvider o'rniga FutureProvider.

import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart'
    show keepAliveFor;
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/models/location_stop.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `LocationHistoryQuery` — `locationHistoryProvider.family` argumenti.
///
/// Record tip: `(childId, fromMs, toMs)`. Riverpod family bitta argument
/// qabul qiladi, vaqtni epoch ms bilan o'rab uzatamiz (DateTime record
/// equality'ni bo'zadi — har build yangi instance, family cache miss).
typedef LocationHistoryQuery = ({String childId, int fromMs, int toMs});

/// Bola harakat tarixini Backend'dan oladi.
final locationHistoryProvider = FutureProvider.autoDispose
    .family<List<ChildLocation>, LocationHistoryQuery>((ref, query) async {
      final auth = ref.watch(backendAuthProvider);
      if (auth is! AuthAuthenticated) return const [];
      // SCR-09: autoDispose + qisqa kesh — har sana-oralig'i kaliti avval
      // ABADIY keshda qolardi (cheksiz xotira o'sishi).
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
      keepAliveFor(ref, const Duration(minutes: 2)); // SCR-09

      final repo = ref.watch(backendLocationRepositoryProvider);
      return repo.getStops(
        childId: query.childId,
        from: DateTime.fromMillisecondsSinceEpoch(query.fromMs),
        to: DateTime.fromMillisecondsSinceEpoch(query.toMs),
      );
    });
