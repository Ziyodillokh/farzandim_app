// ─────────────────────────────────────────────────────────────────────
// ListenRepository — jonli eshitish sessiyasini boshqarish (REST)
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ OVOZ SHU YERDAN O'TMAYDI. Ovoz WebRTC (P2P) orqali to'g'ridan-to'g'ri
// bola→ota-ona keladi. Bu repository faqat sessiyani boshlaydi/to'xtatadi.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final listenRepositoryProvider = Provider<ListenRepository>((ref) {
  return ListenRepository(dio: ref.watch(dioClientProvider));
});

/// Boshlangan sessiya — WebRTC signaling shu `id` bo'yicha yo'naltiriladi.
@immutable
class ListenSession {
  const ListenSession({required this.id, required this.status});

  factory ListenSession.fromJson(Map<String, dynamic> json) {
    return ListenSession(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
    );
  }

  final String id;
  final String status;
}

class ListenRepository {
  ListenRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Eshitishni boshlaydi → backend bola qurilmasini uyg'otadi.
  /// Muvaffaqiyatsiz bo'lsa `null`.
  Future<ListenSession?> start(String childId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/listen-sessions',
      );
      final data = res.data;
      if (data == null) return null;
      return ListenSession.fromJson(data);
    } on DioException catch (e) {
      debugPrint('ListenRepository.start xato ${e.response?.statusCode}');
      return null;
    }
  }

  /// Sessiyani to'xtatadi (ota-ona to'xtatish tugmasi).
  Future<void> end(String sessionId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/listen-sessions/$sessionId/end');
    } on DioException catch (e) {
      debugPrint('ListenRepository.end xato ${e.response?.statusCode}');
    }
  }
}
