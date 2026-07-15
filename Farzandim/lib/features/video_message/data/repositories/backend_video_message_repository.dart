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
  }) : _dio = dio,
       _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Video messages ro'yxati (raw JSON, model alohida feature qo'shsa).
  ///
  /// Paginatsiya: `peerId` — faqat shu user bilan yozishmalar,
  /// `before` — shu vaqtdan eski sahifa (cursor), `limit` — sahifa hajmi.
  Future<List<Map<String, dynamic>>> getMessages({
    String? role,
    String? peerId,
    DateTime? before,
    int? limit,
  }) async {
    try {
      final query = <String, dynamic>{
        if (role != null) 'role': role,
        if (peerId != null) 'peerId': peerId,
        if (before != null) 'before': before.toUtc().toIso8601String(),
        if (limit != null) 'limit': limit,
      };
      final response = await _dio.get<Map<String, dynamic>>(
        '/video-messages',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['messages'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendVideoMessageRepository.getMessages: $e');
      // Eski sahifa so'rovi xatosini chaqiruvchi bilishi kerak.
      if (before != null) rethrow;
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
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        'file': await MultipartFile.fromFile(videoFile.path),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/video-messages',
        data: formData,
        // Dio'ning umumiy `sendTimeout` = 30s — VIDEO uchun juda kam (30
        // soniyalik dumaloq video ~5-15 MB; mobil internetda 30 soniyada
        // yuklanmaydi → timeout → "video ketmadi"). Backend 100 MB ruxsat
        // beradi, shuning uchun yuklashga alohida uzun muddat.
        options: Options(
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 2),
        ),
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

  /// Signed URL (1 soat) — video playback (eski; proxy bilan almashtirildi).
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

  /// Video proxy stream URL — `video_player` shu URL'dan to'g'ridan o'ynaydi
  /// va birinchi kadrni thumbnail sifatida ko'rsatadi (auth header'siz,
  /// @Public). Signed URL telefondan yetib bo'lmaydi — shuning uchun proxy.
  String videoStreamUrl(String messageId) =>
      '${_dio.options.baseUrl}/video-messages/$messageId/stream';

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
