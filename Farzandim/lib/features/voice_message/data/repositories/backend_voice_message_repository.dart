// ─────────────────────────────────────────────────────────────────────
// BackendVoiceMessageRepository — Parent App Backend Voice (Sprint 4.4.5)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Child App'dagi versiya bilan parallel — bir xil API):
//   POST /api/voice-messages           multipart audio + receiverId
//   GET  /api/voice-messages?role=     {messages: [...]}
//   GET  /api/voice-messages/:id/file  {url, expiresIn: 3600}
//   PUT  /api/voice-messages/:id/read
//   DELETE /api/voice-messages/:id
//   WS   voice:received → user:<receiverId> room
//
// Backend Claude security:
// - sender ↔ receiver family check
// - senderId === receiverId → 400

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendVoiceMessageRepositoryProvider =
    Provider<BackendVoiceMessageRepository>((ref) {
  return BackendVoiceMessageRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendVoiceMessageRepository {
  BackendVoiceMessageRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Voice xabarlar ro'yxati. `role`:
  /// - `null` → barchasi (sent + received)
  /// - `'received'` → faqat olganlar
  /// - `'sent'` → faqat yuborganlar
  Future<List<Map<String, dynamic>>> getMessagesRaw({String? role}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/voice-messages',
        queryParameters: role != null ? {'role': role} : null,
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['messages'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendVoiceMessageRepository.getMessages: $e');
      return const [];
    }
  }

  /// Multipart audio upload (Parent → Child).
  Future<String?> sendMessage({
    required String receiverId,
    required File audioFile,
    required int durationSeconds,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'receiverId': receiverId,
        'durationSeconds': durationSeconds,
        'file': await MultipartFile.fromFile(audioFile.path),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/voice-messages',
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
        'BackendVoiceMessageRepository.sendMessage xato '
        '${e.response?.statusCode} — ${e.message}',
      );
      rethrow;
    }
  }

  /// Text xabar yuborish (Telegram-style chat).
  /// `POST /voice-messages/text` { receiverId, text } — audio yo'q.
  /// Backend Socket.io orqali receiver'ga real-time emit qiladi.
  Future<String?> sendText({
    required String receiverId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/voice-messages/text',
        data: <String, dynamic>{
          'receiverId': receiverId,
          'text': trimmed,
        },
      );
      return response.data?['id'] as String?;
    } on DioException catch (e) {
      debugPrint(
        'BackendVoiceMessageRepository.sendText xato '
        '${e.response?.statusCode} — ${e.message}',
      );
      rethrow;
    }
  }

  /// Media (rasm/hujjat) yuborish — multipart MinIO upload (`chat` bucket).
  /// `POST /voice-messages/media` { file, receiverId, caption? }.
  Future<String?> sendMedia({
    required String receiverId,
    required File file,
    String? caption,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final trimmedCaption = caption?.trim();
      final formData = FormData.fromMap({
        'receiverId': receiverId,
        if (trimmedCaption != null && trimmedCaption.isNotEmpty)
          'caption': trimmedCaption,
        'file': await MultipartFile.fromFile(file.path),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/voice-messages/media',
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
        'BackendVoiceMessageRepository.sendMedia xato '
        '${e.response?.statusCode} — ${e.message}',
      );
      rethrow;
    }
  }

  /// Media fayl proxy URL — auth header'siz `Image.network` / yuklab olish
  /// uchun (signed URL telefondan yetib bo'lmaydigan ichki MinIO manzilini
  /// chetlaydi; support/avatar proxy bilan bir xil).
  String mediaUrl(String key) =>
      '${_dio.options.baseUrl}/voice-messages/media/$key';

  /// Audio fayl signed URL (1 soat amal qiladi).
  Future<String?> getFileUrl(String messageId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/voice-messages/$messageId/file',
      );
      return response.data?['url'] as String?;
    } on DioException {
      return null;
    }
  }

  /// Hozirgi user'ga kelgan barcha o'qilmagan xabarlarni bulk mark.
  /// `fromUserId` berilsa — faqat shu sender'dan kelganlar.
  ///
  /// Sprint 4.4.31: chat ekran ochilganda 1 ta chaqiruv bilan
  /// barcha unread'larni belgilash (tap-by-tap o'rniga).
  Future<bool> markAllRead({String? fromUserId}) async {
    try {
      await _dio.post<void>(
        '/voice-messages/read-all',
        data: <String, dynamic>{
          if (fromUserId != null) 'fromUserId': fromUserId,
        },
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendVoiceMessageRepository.markAllRead xato '
        '${e.response?.statusCode}',
      );
      return false;
    }
  }

  /// Xabarni ko'rilgan deb belgilash.
  ///
  /// **Eslatma:** body sifatida bo'sh `{}` yuboriladi. Dio default
  /// `Content-Type: application/json` yuboradi va Fastify 5 JSON parser
  /// bo'sh body'ni qabul qilmaydi (`FST_ERR_CTP_INVALID_JSON_BODY` 400).
  Future<bool> markAsRead(String messageId) async {
    try {
      await _dio.put<void>(
        '/voice-messages/$messageId/read',
        data: <String, dynamic>{},
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'BackendVoiceMessageRepository.markAsRead xato '
        '${e.response?.statusCode} body=${e.response?.data}',
      );
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await _dio.delete<void>('/voice-messages/$messageId');
      return true;
    } on DioException {
      return false;
    }
  }

  /// `voice:received` WS event stream — yangi xabar real-time'da keladi.
  Stream<dynamic> voiceReceivedStream() {
    return _socketClient.eventStream('voice:received');
  }
}
