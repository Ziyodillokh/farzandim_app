// ─────────────────────────────────────────────────────────────────────
// BackendPairRequestRepository — Re-pair flow (Backend 0.6.0)
// ─────────────────────────────────────────────────────────────────────
//
// Endpoint'lar:
//   GET    /api/children/:childId/pair-requests?status=PENDING
//   POST   /api/children/:childId/pair-requests/:id/approve
//   POST   /api/children/:childId/pair-requests/:id/reject
//
// WS event'lar (parent room):
//   pair_request:created   yangi request (FCM push ham keladi)
//   pair_request:approved  yopildi (parent o'zi yoki boshqa parent)
//   pair_request:rejected  yopildi

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/pair_requests/data/models/pair_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendPairRequestRepositoryProvider =
    Provider<BackendPairRequestRepository>((ref) {
  return BackendPairRequestRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendPairRequestRepository {
  BackendPairRequestRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Bola uchun pending pair request'lar.
  Future<List<PairRequest>> getPendingRequests(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/pair-requests',
        queryParameters: {'status': 'PENDING'},
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['requests'] as List<dynamic>? ?? const [];
      return list
          .map((m) =>
              PairRequest.fromBackendJson(m as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // EH-09: yutmaymiz — offline'da yolg'on "so'rov yo'q" ko'rinardi.
      debugPrint('BackendPairRequestRepository.getPending: $e');
      rethrow;
    }
  }

  /// Pair request tasdiqlash (eski Child User soft-delete + yangisi).
  Future<bool> approve({
    required String childId,
    required String requestId,
  }) async {
    try {
      await _dio.post<void>(
        '/children/$childId/pair-requests/$requestId/approve',
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendPairRequestRepository.approve xato '
        '${e.response?.statusCode}',
      );
      return false;
    }
  }

  /// Pair request rad etish.
  Future<bool> reject({
    required String childId,
    required String requestId,
  }) async {
    try {
      await _dio.post<void>(
        '/children/$childId/pair-requests/$requestId/reject',
      );
      return true;
    } on DioException catch (e) {
      debugPrint('BackendPairRequestRepository.reject: $e');
      return false;
    }
  }

  /// WS streams.
  Stream<dynamic> createdStream() =>
      _socketClient.eventStream('pair_request:created');
  Stream<dynamic> approvedStream() =>
      _socketClient.eventStream('pair_request:approved');
  Stream<dynamic> rejectedStream() =>
      _socketClient.eventStream('pair_request:rejected');
}
