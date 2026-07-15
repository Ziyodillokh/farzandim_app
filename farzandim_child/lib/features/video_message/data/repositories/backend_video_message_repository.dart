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
      // eski sahifa so'rovi xatosini chaqiruvchi bilishi kerak —
      // bo'sh ro'yxat "tarix tugadi" degani emas
      if (before != null) rethrow;
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
      return _post(formData, onProgress);
    } on DioException catch (e) {
      debugPrint(
        'BackendVideoMessageRepository.sendMessage: '
        '${e.response?.statusCode} — ${e.message}',
      );
      rethrow;
    }
  }

  /// Web-friendly variant — fayl tizimisiz (dart:io File yo'q).
  /// Camera plugin'dan kelgan `Uint8List` baytlarini to'g'ridan-to'g'ri
  /// yuboradi. Mobile'da ham ishlaydi, lekin asosan web preview uchun.
  Future<String?> sendMessageBytes({
    required String receiverId,
    required Uint8List bytes,
    String filename = 'video.webm',
    String? mimeType,
    int? durationSeconds,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Brauzer kamera odatda WebM beradi (Chrome MediaRecorder default).
      // Filename'da kengaytma yo'q bo'lsa Dio mimetype'ni
      // application/octet-stream'ga qo'yadi → backend 415. Shu sababli
      // contentType'ni majburiy beramiz.
      final mime = mimeType ?? _guessMimeFromName(filename) ?? 'video/webm';
      final fname = filename.contains('.') ? filename : '$filename.webm';
      final formData = FormData.fromMap({
        'receiverId': receiverId,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fname,
          contentType: DioMediaType.parse(mime),
        ),
      });
      return _post(formData, onProgress);
    } on DioException catch (e) {
      debugPrint(
        'BackendVideoMessageRepository.sendMessageBytes: '
        '${e.response?.statusCode} — ${e.message}',
      );
      rethrow;
    }
  }

  /// Fayl kengaytmasi bo'yicha video MIME aniqlash. Brauzer kamera
  /// odatda webm beradi; mobile (camera plugin) — mp4 yoki mov.
  String? _guessMimeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.3gp')) return 'video/3gpp';
    return null;
  }

  Future<String?> _post(
    FormData formData,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/video-messages',
        data: formData,
        // Dio'ning umumiy `sendTimeout` = 30s — bu VIDEO uchun juda kam:
        // 30 soniyalik dumaloq video ~5-15 MB, mobil internetda 30 soniyada
        // yuklanmaydi → timeout → "video ketmadi". Backend 100 MB ruxsat
        // beradi, shuning uchun yuklashga alohida uzun muddat beramiz.
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

  /// Signed URL (1 soat) — eski; proxy stream bilan almashtirildi (signed URL
  /// telefondan yetib bo'lmaydi).
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

  /// Video proxy stream URL — `video_player` shu URL'dan to'g'ridan o'ynaydi
  /// (auth header'siz, @Public). Signed URL telefondan yetib bo'lmaydi —
  /// shuning uchun proxy (ota-ona ilovasi bilan bir xil).
  String videoStreamUrl(String messageId) =>
      '${_dio.options.baseUrl}/video-messages/$messageId/stream';

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
