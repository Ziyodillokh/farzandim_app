// ─────────────────────────────────────────────────────────────────────
// BackendGeoZoneRepository — Backend Geo Zones API (Sprint 4.4.3)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET    /api/children/:childId/geo-zones    → {zones, count}
//   POST   /api/children/:childId/geo-zones    body: GeoZone payload
//   GET    /api/geo-zones/:id                  → GeoZone
//   PUT    /api/geo-zones/:id                  body: partial
//   DELETE /api/geo-zones/:id
//   WS     geo_zone:created/updated/deleted    → child room
//   WS     geo_zone:alert                      → user + child room
//
// Geofence detection backend'da avtomatik (POST /api/location ichida).
// Alert WS event'i Parent App'ga keladi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendGeoZoneRepositoryProvider =
    Provider<BackendGeoZoneRepository>((ref) {
  final auth = ref.watch(backendAuthProvider);
  final currentUserId = auth is AuthAuthenticated ? auth.user.id : '';
  return BackendGeoZoneRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
    currentUserId: currentUserId,
  );
});

class BackendGeoZoneRepository {
  BackendGeoZoneRepository({
    required Dio dio,
    required SocketClient socketClient,
    required String currentUserId,
  })  : _dio = dio,
        _socketClient = socketClient,
        _currentUserId = currentUserId;

  final Dio _dio;
  final SocketClient _socketClient;
  final String _currentUserId;

  /// Bola uchun geo-zonalar ro'yxati.
  Future<List<GeoZone>> getZones(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/geo-zones',
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['zones'] as List<dynamic>? ?? const [];
      return list
          .map(
            (e) => GeoZone.fromBackendJson(
              e as Map<String, dynamic>,
              parentUid: _currentUserId,
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendGeoZoneRepository.getZones: $e');
      return const [];
    }
  }

  /// Bola uchun geo-zona kirish/chiqish hodisalari tarixi (Sprint 6 P2).
  Future<List<GeoZoneEvent>> getEvents(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/geo-zone-events',
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['events'] as List<dynamic>? ?? const [];
      return list
          .map(
            (e) => GeoZoneEvent.fromBackendJson(
              e as Map<String, dynamic>,
              childId: childId,
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendGeoZoneRepository.getEvents: $e');
      return const [];
    }
  }

  /// Yangi zona yaratish.
  Future<GeoZone?> createZone({
    required String childId,
    required GeoZone zone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/geo-zones',
        data: zone.toBackendJson(),
      );
      final data = response.data;
      if (data == null) return null;
      return GeoZone.fromBackendJson(data, parentUid: _currentUserId);
    } on DioException catch (e) {
      debugPrint('BackendGeoZoneRepository.createZone: $e');
      rethrow;
    }
  }

  /// Zonani yangilash (partial).
  Future<GeoZone?> updateZone({
    required String zoneId,
    required GeoZone zone,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/geo-zones/$zoneId',
        data: zone.toBackendJson(),
      );
      final data = response.data;
      if (data == null) return null;
      return GeoZone.fromBackendJson(data, parentUid: _currentUserId);
    } on DioException catch (e) {
      debugPrint('BackendGeoZoneRepository.updateZone: $e');
      rethrow;
    }
  }

  /// Zonani o'chirish.
  Future<bool> deleteZone(String zoneId) async {
    try {
      await _dio.delete<void>('/geo-zones/$zoneId');
      return true;
    } on DioException {
      return false;
    }
  }

  /// Zona o'zgarishlari WS stream (created/updated/deleted) — child room.
  /// Cache invalidate uchun ishlatiladi.
  Stream<dynamic> zoneEventsStream() {
    return _socketClient.eventStream('geo_zone:created');
  }

  Stream<dynamic> zoneUpdatedStream() {
    return _socketClient.eventStream('geo_zone:updated');
  }

  Stream<dynamic> zoneDeletedStream() {
    return _socketClient.eventStream('geo_zone:deleted');
  }

  /// Geo-zone alert WS event (entry/exit). Push handler ham keladi
  /// (Backend FCM yuboradi), lekin foreground'da WS bilan ham
  /// banner ko'rsatish mumkin.
  ///
  /// Payload: `{ type, event: 'enter'|'exit', zoneId, zoneName,
  /// childId, location }`
  Stream<dynamic> alertStream() {
    return _socketClient.eventStream('geo_zone:alert');
  }
}
