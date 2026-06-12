// ─────────────────────────────────────────────────────────────────────
// SupportAttachmentRepository — biriktirmani backend'ga yuklash + proxy URL
// ─────────────────────────────────────────────────────────────────────
//
// Fayl MinIO'ga yuklanadi (POST /api/support/attachments, multipart) va
// `key` qaytariladi. Key chat xabarida lokal saqlanadi; ko'rsatish/yuklab
// olish proxy orqali bo'ladi (GET /api/support/attachments/:key — @Public,
// signed-URL reachability muammosini chetlaydi, app-icon proxy bilan bir xil).

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final supportAttachmentRepositoryProvider =
    Provider<SupportAttachmentRepository>((ref) {
      return SupportAttachmentRepository(ref.watch(dioClientProvider));
    });

class SupportAttachmentUpload {
  const SupportAttachmentUpload({
    required this.key,
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  final String key;
  final String fileName;
  final String mimeType;
  final int size;
}

class SupportAttachmentRepository {
  SupportAttachmentRepository(this._dio);

  final Dio _dio;

  /// Biriktirmani backend'ga yuklaydi → MinIO `key` qaytaradi.
  /// Mobil: `filePath`; web: `bytes` beriladi.
  Future<SupportAttachmentUpload> upload({
    required String fileName,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final MultipartFile file;
    if (bytes != null) {
      file = MultipartFile.fromBytes(bytes, filename: fileName);
    } else if (filePath != null) {
      file = await MultipartFile.fromFile(filePath, filename: fileName);
    } else {
      throw ArgumentError('filePath yoki bytes berilishi shart');
    }

    final form = FormData.fromMap({'file': file});
    final res = await _dio.post<Map<String, dynamic>>(
      '/support/attachments',
      data: form,
    );
    final data = res.data ?? const <String, dynamic>{};
    return SupportAttachmentUpload(
      key: data['key'] as String? ?? '',
      fileName: data['fileName'] as String? ?? fileName,
      mimeType: data['mimeType'] as String? ?? 'application/octet-stream',
      size: (data['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// Proxy URL — `Image.network` / yuklab olish uchun (auth'siz, @Public).
  String urlForKey(String key) =>
      '${_dio.options.baseUrl}/support/attachments/${Uri.encodeComponent(key)}';

  /// Remote biriktirmani vaqtinchalik papkaga yuklab oladi va lokal yo'lini
  /// qaytaradi (`OpenFilex` bilan ochish uchun). Faqat mobil (web'da emas).
  Future<String> downloadToTemp({
    required String key,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final savePath = '${dir.path}/$safe';
    await _dio.download(urlForKey(key), savePath);
    return savePath;
  }
}
