// ─────────────────────────────────────────────────────────────────────
// BackendVoiceMessageRepository — Backend Voice API (Sprint 4.4.5)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   POST /api/voice-messages           multipart audio + receiverId
//   GET  /api/voice-messages?role=     {messages: [...]}
//   GET  /api/voice-messages/:id/file  {url, expiresIn: 3600}
//   PUT  /api/voice-messages/:id/read
//   DELETE /api/voice-messages/:id
//   WS   voice:received → user:<receiverId> room
//
// Backend Claude security guard'lari (4.4 evening audit):
// - sender ↔ receiver family check (parent ↔ paired child)
// - senderId === receiverId → 400 (o'ziga yuborish blok)

// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/features/voice_message/data/models/voice_message.dart';

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
  }) : _dio = dio,
       _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// WS `voice:received` event stream — Parent yuborganida emit qilinadi.
  Stream<dynamic> voiceReceivedStream() =>
      _socketClient.eventStream('voice:received');

  /// Voice xabarlar ro'yxati.
  ///
  /// `currentUserId` — joriy CHILD user ID (Backend `user.id`).
  /// Pairing state'dan uzatiladi. Voice bubble'da sender directionini
  /// (chap='child o'zining'/o'ng='parent kelgan') aniqlashda kerak.
  ///
  /// `role`: null → barcha; `'sent'`/`'received'` → filter.
  ///
  /// Paginatsiya: `peerId` — faqat shu user bilan yozishmalar,
  /// `before` — shu vaqtdan eski sahifa (cursor), `limit` — sahifa hajmi.
  /// Hech biri berilmasa server eng oxirgi 100 tani qaytaradi.
  Future<List<VoiceMessage>> getMessages({
    required String currentUserId,
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
        '/voice-messages',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['messages'] as List<dynamic>? ?? const [];
      return list
          .map(
            (e) => VoiceMessage.fromBackendJson(
              e as Map<String, dynamic>,
              currentUserId: currentUserId,
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendVoiceMessageRepository.getMessages: $e');
      // eski sahifa so'rovi xatosini chaqiruvchi bilishi kerak —
      // bo'sh ro'yxat "tarix tugadi" degani emas
      if (before != null) rethrow;
      return const [];
    }
  }

  /// Multipart audio upload.
  ///
  /// Backend validatsiya: audio MIME, max 10 MB.
  /// senderId === receiverId → 400 (Backend block).
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
      final data = response.data;
      return data?['id'] as String?;
    } on DioException catch (e) {
      debugPrint(
        'BackendVoiceMessageRepository.sendMessage xato '
        '${e.response?.statusCode} — ${e.message}',
      );
      rethrow;
    }
  }

  /// Text xabar yuborish (Telegram-style chat).
  /// Audio fayl yo'q — `POST /api/voice-messages/text` { receiverId, text }.
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
        data: <String, dynamic>{'receiverId': receiverId, 'text': trimmed},
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
  /// `POST /api/voice-messages/media` { file, receiverId, caption? }.
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
  /// chetlaydi).
  String mediaUrl(String key) =>
      '${_dio.options.baseUrl}/voice-messages/media/$key';

  /// Audio fayl signed URL (1 soat amal qiladi).
  Future<String?> getFileUrl(String messageId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/voice-messages/$messageId/file',
      );
      return response.data?['url'] as String?;
    } on DioException catch (e) {
      debugPrint('BackendVoiceMessageRepository.getFileUrl: $e');
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
  /// bo'sh body'ni `FST_ERR_CTP_INVALID_JSON_BODY` deb 400 qaytarmaydi.
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

  /// Xabarni o'chirish.
  /// O'z matnli xabarini tahrirlash (Telegram-style) —
  /// `PATCH /api/voice-messages/:id/text` { text }.
  Future<bool> updateText(String messageId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/voice-messages/$messageId/text',
        data: <String, dynamic>{'text': trimmed},
      );
      return true;
    } on DioException {
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
}
