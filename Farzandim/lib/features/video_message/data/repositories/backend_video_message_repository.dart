// ─────────────────────────────────────────────────────────────────────
// BackendVideoMessageRepository — Backend Video API (Sprint 4.4.7)
// ─────────────────────────────────────────────────────────────────────
//
// Voice pattern qayta ishlatildi (Backend kontrakt deyarli bir xil).
//
// Backend kontrakt:
//   POST /api/video-messages (multipart, MAX 100 MB) → VideoMessage
//   GET /api/video-messages?role=sent|received → {messages}
//   GET /api/video-messages/:id/file → signed URL (1h)
//   DELETE /api/video-messages/:id
//   WS video:received → user:receiverId room
//
// Backend Claude security (sender ↔ receiver family check,
// senderId !== receiverId 400).

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendVideoMessageRepositoryProvider =
    Provider<BackendVideoMessageRepository>((ref) {
  return BackendVideoMessageRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendVideoMessageRepository {
  BackendVideoMessageRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Video messages ro'yxati (raw JSON, model alohida feature qo'shsa).
  Future<List<Map<String, dynamic>>> getMessages({String? role}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/video-messages',
        queryParameters: role != null ? {'role': role} : null,
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['messages'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendVideoMessageRepository.getMessages: $e');
      return const [];
    }
  }

  /// Multipart video upload.
  Future<String?> sendMessage({
    required String receiverId,
    required File videoFile,
    int? durationSeconds,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'receiverId': receiverId,
        if (durationSeconds != null)
          'durationSeconds': durationSeconds,
        'file': await MultipartFile.fromFile(videoFile.path),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/video-messages',
        data: formData,
        onSendProgress: (count, total) {
          if (total > 0 && onProgress != null) {
            onProgress(count / total);
          }
        },
      );
      return response.data?['id'] as String?;
    } on DioException catch (e) {
      debugPrint(
        'BackendVideoMessageRepository.sendMessage xato '
        '${e.response?.statusCode}',
      );
      rethrow;
    }
  }

  /// Signed URL (1 soat) — video playback.
  Future<String?> getFileUrl(String messageId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/video-messages/$messageId/file',
      );
      return response.data?['url'] as String?;
    } on DioException {
      return null;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await _dio.delete<void>('/video-messages/$messageId');
      return true;
    } on DioException {
      return false;
    }
  }

  /// WS `video:received` — yangi video keldi.
  Stream<dynamic> receivedStream() =>
      _socketClient.eventStream('video:received');
}
