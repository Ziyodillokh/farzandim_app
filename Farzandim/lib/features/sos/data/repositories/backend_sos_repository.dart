// ─────────────────────────────────────────────────────────────────────
// BackendSosRepository — Backend SOS Alerts API (Sprint 4.4.7)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST /api/children/:childId/sos-alerts → SosAlert (Child trigger)
//   GET /api/sos-alerts?status=ACTIVE → {alerts, count}
//   PUT /api/sos-alerts/:id/resolve → status: RESOLVED
//   WS sos:received → parent user + child room (HIGH priority push)
//   WS sos:resolved → child user + child room

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendSosRepositoryProvider = Provider<BackendSosRepository>((ref) {
  return BackendSosRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendSosRepository {
  BackendSosRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// SOS alert ro'yxati (Parent monitoring).
  /// `status`: 'ACTIVE' (default) | 'RESOLVED'.
  ///
  /// MUHIM (P0-3): xato YUTILMAYDI — rethrow. Avval xatoda `[]` qaytarilardi
  /// va ota-ona FAVQULODDA vaziyatda offline bo'lsa ekranda yolg'on
  /// "SOS signallari yo'q — hammasi tinch" ko'rardi. Endi provider
  /// AsyncValue.error'ga tushadi va ekran aniq xato + retry ko'rsatadi
  /// (sos_alerts_list_screen'da error branch allaqachon bor).
  Future<List<Map<String, dynamic>>> getAlerts({
    String status = 'ACTIVE',
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sos-alerts',
        queryParameters: {'status': status, 'limit': limit},
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['alerts'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendSosRepository.getAlerts: $e');
      rethrow;
    }
  }

  /// Parent SOS alert'ni hal qildi (yopadi).
  Future<bool> resolveAlert(String alertId) async {
    try {
      await _dio.put<void>('/sos-alerts/$alertId/resolve');
      return true;
    } on DioException {
      return false;
    }
  }

  /// WS streams.
  Stream<dynamic> receivedStream() =>
      _socketClient.eventStream('sos:received');
  Stream<dynamic> resolvedStream() =>
      _socketClient.eventStream('sos:resolved');
}
