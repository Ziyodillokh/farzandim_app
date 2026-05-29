// ─────────────────────────────────────────────────────────────────────
// BackendPhotoRequestRepository — Child App photo response (Sprint 4.4.9.4)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Child JWT bilan):
//   GET /api/children/:childId/photo-requests?status=PENDING → list
//   POST /api/photo-requests/:id/upload (multipart) → COMPLETED
//   PUT /api/photo-requests/:id/decline → DECLINED
//
// State machine: PENDING (parent yaratdi) → COMPLETED (bola upload) yoki
// DECLINED (bola rad etdi).
//
// WS `photo_request:received` (bola room) — yangi parent so'rovi keldi.

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendPhotoRequestRepositoryProvider =
    Provider<BackendPhotoRequestRepository>((ref) {
  return BackendPhotoRequestRepository(dio: ref.watch(dioClientProvider));
});

class BackendPhotoRequestRepository {
  BackendPhotoRequestRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Bola uchun pending photo requests ro'yxati.
  Future<List<Map<String, dynamic>>> getPendingRequests({
    required String childId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/photo-requests',
        queryParameters: {'status': 'PENDING'},
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['requests'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint(
        'BackendPhotoRequestRepository.getPendingRequests: $e',
      );
      return const [];
    }
  }

  /// Bola rasm yuklaydi (multipart) — PENDING → COMPLETED.
  /// Backend image MAX 15 MB.
  Future<bool> uploadPhoto({
    required String requestId,
    required File photoFile,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(photoFile.path),
      });
      await _dio.post<Map<String, dynamic>>(
        '/photo-requests/$requestId/upload',
        data: formData,
        onSendProgress: (count, total) {
          if (total > 0 && onProgress != null) {
            onProgress(count / total);
          }
        },
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendPhotoRequestRepository.uploadPhoto xato '
        '${e.response?.statusCode}',
      );
      return false;
    }
  }

  /// Bola rad etadi — PENDING → DECLINED.
  Future<bool> declineRequest(String requestId) async {
    try {
      await _dio.put<void>('/photo-requests/$requestId/decline');
      return true;
    } on DioException {
      return false;
    }
  }
}
