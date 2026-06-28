// Backend SOS alert API: ro'yxat, resolve va WS sos:received/sos:resolved.

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
  BackendSosRepository({required Dio dio, required SocketClient socketClient})
    : _dio = dio,
      _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// SOS alert ro'yxati. `status`: 'ACTIVE' (default) | 'RESOLVED'.
  ///
  /// Xato yutilmaydi — rethrow. Xatoda `[]` qaytarilsa, offline ota-ona
  /// favqulodda vaziyatda yolg'on "hammasi tinch" ekranini ko'rardi;
  /// rethrow bilan ekran aniq xato + retry ko'rsatadi.
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

  Stream<dynamic> receivedStream() => _socketClient.eventStream('sos:received');
  Stream<dynamic> resolvedStream() => _socketClient.eventStream('sos:resolved');
}
