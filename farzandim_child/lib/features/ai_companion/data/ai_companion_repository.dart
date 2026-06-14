// ─────────────────────────────────────────────────────────────────────
// AiCompanionRepository — Faro AI hamroh API (#65)
// ─────────────────────────────────────────────────────────────────────
//
//   POST /api/ai/chat { message } → AiMessage (assistant javobi)
//   GET  /api/ai/history          → { messages: [...] }

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/ai_companion/data/ai_message.dart';

final aiCompanionRepositoryProvider =
    Provider<AiCompanionRepository>((ref) {
  return AiCompanionRepository(dio: ref.watch(dioClientProvider));
});

/// Kunlik chegara (429) yoki tarmoq xatosi — UI'ga ko'rsatish uchun.
class AiChatException implements Exception {
  AiChatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiCompanionRepository {
  AiCompanionRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<AiMessage> send(String message) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/ai/chat',
        data: {'message': message},
      );
      return AiMessage.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final msg = (e.response?.data is Map)
            ? (e.response?.data['message'] as String?)
            : null;
        throw AiChatException(
          msg ?? 'Bugungi suhbat chegarasiga yetding 😊',
        );
      }
      throw AiChatException('Hozircha javob bera olmadim. Qayta urinib ko\'r.');
    }
  }

  Future<List<AiMessage>> history() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/ai/history');
      final items = (res.data?['messages'] as List<dynamic>?) ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AiMessage.fromJson)
          .toList();
    } on DioException {
      return const [];
    }
  }
}
