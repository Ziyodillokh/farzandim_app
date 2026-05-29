// ─────────────────────────────────────────────────────────────────────
// BackendVideoMessageRepository — Child App Video API (Sprint 4.4.9.4)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Voice pattern qayta ishlatildi):
//   POST /api/video-messages (multipart MAX 100 MB) → VideoMessage
//   GET /api/video-messages?role=sent|received → {messages}
//   GET /api/video-messages/:id/file → signed URL 1h
//   PUT /api/video-messages/:id/read
//   DELETE /api/video-messages/:id
//   WS video:received → user:receiverId
//
// Backend Claude security: senderId !== receiverId 400.

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
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

  /// Video messages ro'yxati (raw JSON — caller modelni o'zi parse qiladi).
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

  /// Multipart video upload (Child → Parent).
  /// Returns: yaratilgan VideoMessage `id`.
  Future<String?> sendMessage({
    required String receiverId,
    required File videoFile,
    int? durationSeconds,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'receiverId': receiverId,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
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

  /// Signed URL (1 soat) — video playback uchun.
  Future<String?> getFileUrl(String messageId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/video-messages/$messageId/file',
      );
      return response.data?['url'] as String?;
    } on DioException catch (e) {
      debugPrint('BackendVideoMessageRepository.getFileUrl: $e');
      return null;
    }
  }

  /// Ko'rilgan deb belgilash.
  Future<bool> markAsRead(String messageId) async {
    try {
      await _dio.put<void>(
        '/video-messages/$messageId/read',
        data: <String, dynamic>{},
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendVideoMessageRepository.markAsRead xato '
        '${e.response?.statusCode}',
      );
      return false;
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
