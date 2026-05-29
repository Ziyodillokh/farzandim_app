// ─────────────────────────────────────────────────────────────────────
// geo_zone_event_providers — Backend geo-zona hodisalari tarixi (Sprint 6 P2)
// ─────────────────────────────────────────────────────────────────────
//
// Backend endpoint: GET /api/children/:childId/geo-zone-events
// Real-time alert WS (`geo_zone:alert`) bilan birga ishlaydi — bu yer tarix.
// Yangilash: `ref.invalidate(geoZoneEventsProvider(childId))`.

import 'package:farzandim/features/geo_zones/data/models/geo_zone_event.dart';
import 'package:farzandim/features/geo_zones/data/repositories/backend_geo_zone_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun geo-zona kirish/chiqish hodisalari tarixi.
final geoZoneEventsProvider =
    FutureProvider.family<List<GeoZoneEvent>, String>((ref, childId) async {
  final repo = ref.watch(backendGeoZoneRepositoryProvider);
  return repo.getEvents(childId);
});

/// Oxirgi 24 soatdagi hodisalar soni — geo-zonalar ro'yxati ekranida badge.
final geoZoneEventsCountProvider =
    FutureProvider.family<int, String>((ref, childId) async {
  final events = await ref.watch(geoZoneEventsProvider(childId).future);
  final dayAgo = DateTime.now().subtract(const Duration(hours: 24));
  return events.where((e) => e.timestamp.isAfter(dayAgo)).length;
});
