// ─────────────────────────────────────────────────────────────────────
// geo_zones_provider — Backend Geo Zones (Sprint 4.4.3)
// ─────────────────────────────────────────────────────────────────────
//
// Eski: Firestore stream + Firebase Auth
// Yangi: Backend REST + WS `geo_zone:created/updated/deleted` real-time.
//
// Geofence detection backend'da avtomatik (POST /api/location). Alert
// `geo_zone:alert` WS event'i orqali kelishi mumkin (foreground'da).

import 'dart:async';

import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/data/repositories/backend_geo_zone_repository.dart';
import 'package:farzandim/features/location/presentation/providers/location_mock.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola uchun barcha geo-zonalar — Backend fetch + WS real-time refresh.
///
/// Backend kontract: `GET /api/children/:childId/geo-zones` → `{zones, count}`.
/// WS `geo_zone:created/updated/deleted` child room'da emit qilinadi
/// → cache invalidate orqali yangi ro'yxat fetch qilinadi.
final geoZonesProvider = StreamProvider.family<List<GeoZone>, String>((
  ref,
  childId,
) async* {
  // MOCK (UI preview): soxta Uy/Maktab zonalari.
  if (kLocationMock) {
    yield mockZones(childId);
    return;
  }
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) {
    yield const <GeoZone>[];
    return;
  }

  final repo = ref.watch(backendGeoZoneRepositoryProvider);

  // Initial fetch.
  yield await repo.getZones(childId);

  // WS event listeners — yangi/yangilangan/o'chirilgan zonalar bo'lsa
  // ro'yxatni qayta yuklab yuboramiz. Backend WS event'lari `childId`
  // payload'da bo'lishi mumkin — filter qilamiz.
  final controller = StreamController<List<GeoZone>>();

  Future<void> refresh() async {
    if (controller.isClosed) return;
    try {
      final zones = await repo.getZones(childId);
      if (!controller.isClosed) controller.add(zones);
    } catch (_) {
      // WS-triggered refresh xatosi — oxirgi ro'yxat saqlanadi (EH-09:
      // repo endi throw qiladi; listener callback'da unhandled bo'lmasin).
    }
  }

  final createdSub = repo.zoneEventsStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });
  final updatedSub = repo.zoneUpdatedStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });
  final deletedSub = repo.zoneDeletedStream().listen((data) {
    if (data is Map && data['childId'] == childId) refresh();
  });

  ref.onDispose(() {
    createdSub.cancel();
    updatedSub.cancel();
    deletedSub.cancel();
    controller.close();
  });

  yield* controller.stream;
});

/// Bitta zona `id` bo'yicha — edit ekrani uchun. Sync access.
final geoZoneByIdProvider =
    Provider.family<GeoZone?, ({String childId, String zoneId})>((ref, args) {
      final zones =
          ref.watch(geoZonesProvider(args.childId)).valueOrNull ??
          const <GeoZone>[];
      for (final zone in zones) {
        if (zone.id == args.zoneId) return zone;
      }
      return null;
    });

/// Geo-zone alert WS event stream — UI banner/notification uchun.
///
/// Payload: `{ type, event: 'enter'|'exit', zoneId, zoneName, childId,
/// location: {latitude, longitude} }`.
///
/// Backend `POST /api/location` ichida entry/exit detect qilib emit
/// qiladi (parent + child rooms). Parent auto-join user room — har
/// alert keladi.
final geoZoneAlertProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final auth = ref.watch(backendAuthProvider);
  if (auth is! AuthAuthenticated) return const Stream.empty();
  final repo = ref.watch(backendGeoZoneRepositoryProvider);
  return repo
      .alertStream()
      .map((data) {
        if (data is Map<String, dynamic>) return data;
        return <String, dynamic>{};
      })
      .where((m) => m.isNotEmpty);
});

/// Geo-zona action'lari (add/update/delete) notifier'i.
class GeoZoneActionsNotifier extends StateNotifier<AsyncValue<void>> {
  GeoZoneActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  BackendGeoZoneRepository get _repo =>
      _ref.read(backendGeoZoneRepositoryProvider);

  /// Yangi zona qo'shish.
  Future<Result<void>> addZone({
    required String childId,
    required String name,
    required GeoZoneType type,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    bool notifyOnEnter = true,
    bool notifyOnExit = true,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      // GeoZone builder — Backend faqat name/centerLat/centerLng/
      // radiusMeters/alertOnEnter/alertOnExit oladi.
      final zone = GeoZone(
        id: '',
        parentUid: '',
        childId: childId,
        name: name,
        type: type,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        notifyOnEnter: notifyOnEnter,
        notifyOnExit: notifyOnExit,
        icon: icon,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repo.createZone(childId: childId, zone: zone);
      // Provider'ni yangilash uchun invalidate (WS event kelmagan bo'lsa).
      _ref.invalidate(geoZonesProvider(childId));
      state = const AsyncValue.data(null);
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// Mavjud zonani yangilash.
  Future<Result<void>> updateZone({
    required String childId,
    required String zoneId,
    required GeoZone current,
    String? name,
    GeoZoneType? type,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? notifyOnEnter,
    bool? notifyOnExit,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = current.copyWith(
        name: name,
        type: type,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        notifyOnEnter: notifyOnEnter,
        notifyOnExit: notifyOnExit,
        icon: icon,
        updatedAt: DateTime.now(),
      );
      await _repo.updateZone(zoneId: zoneId, zone: updated);
      _ref.invalidate(geoZonesProvider(childId));
      state = const AsyncValue.data(null);
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }

  /// Zonani o'chirish.
  Future<Result<void>> deleteZone({
    required String childId,
    required String zoneId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ok = await _repo.deleteZone(zoneId);
      if (ok) _ref.invalidate(geoZonesProvider(childId));
      state = const AsyncValue.data(null);
      return ok
          ? const Result<void>.success()
          : const Result<void>.failure('Amal bajarilmadi');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e.toString());
    }
  }
}

/// Geo-zona action'lari provider'i.
final geoZoneActionsProvider =
    StateNotifierProvider<GeoZoneActionsNotifier, AsyncValue<void>>(
      GeoZoneActionsNotifier.new,
    );
