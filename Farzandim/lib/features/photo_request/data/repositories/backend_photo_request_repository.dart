// ─────────────────────────────────────────────────────────────────────
// BackendPhotoRequestRepository — Backend Photo Requests API (Sprint 4.4.7)
// ─────────────────────────────────────────────────────────────────────
//
// State machine: PENDING → COMPLETED (child upload) | DECLINED (child).
//
// Backend kontrakt:
//   GET /api/children/:childId/photo-requests → {requests, count}
//   POST /api/children/:childId/photo-requests (parent) → PENDING
//   POST /api/photo-requests/:id/upload (child, multipart) → COMPLETED
//   PUT /api/photo-requests/:id/decline (child) → DECLINED
//   GET /api/photo-requests/:id/file → signed URL (1 soat)
//   DELETE /api/photo-requests/:id (parent)
//   WS photo_request:created/received/completed/declined

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendPhotoRequestRepositoryProvider =
    Provider<BackendPhotoRequestRepository>((ref) {
  return BackendPhotoRequestRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendPhotoRequestRepository {
  BackendPhotoRequestRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Bola uchun photo requests ro'yxati.
  /// `status`: PENDING | COMPLETED | DECLINED yoki null (barchasi).
  Future<List<Map<String, dynamic>>> getRequests({
    required String childId,
    String? status,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/photo-requests',
        queryParameters: {
          if (status != null) 'status': status,
          'limit': limit,
        },
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['requests'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendPhotoRequestRepository.getRequests: $e');
      return const [];
    }
  }

  /// Parent yangi photo request yaratadi (PENDING).
  /// `message` — ixtiyoriy ("Bog'da nima qilyapsan?").
  Future<Map<String, dynamic>?> createRequest({
    required String childId,
    String? message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/photo-requests',
        data: {if (message != null) 'message': message},
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  /// Signed URL — rasm download (1 soat amal qiladi).
  Future<String?> getFileUrl(String requestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/photo-requests/$requestId/file',
      );
      return response.data?['url'] as String?;
    } on DioException {
      return null;
    }
  }

  /// Parent photo request'ni o'chiradi.
  Future<bool> deleteRequest(String requestId) async {
    try {
      await _dio.delete<void>('/photo-requests/$requestId');
      return true;
    } on DioException {
      return false;
    }
  }

  // WS streams.
  Stream<dynamic> createdStream() =>
      _socketClient.eventStream('photo_request:created');
  Stream<dynamic> receivedStream() =>
      _socketClient.eventStream('photo_request:received');
  Stream<dynamic> completedStream() =>
      _socketClient.eventStream('photo_request:completed');
  Stream<dynamic> declinedStream() =>
      _socketClient.eventStream('photo_request:declined');
}
