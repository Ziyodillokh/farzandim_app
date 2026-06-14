// ─────────────────────────────────────────────────────────────────────
// AiHistoryRepository (Parent) — bola AI suhbat tarixi (#70)
// ─────────────────────────────────────────────────────────────────────
//
//   GET /api/children/:id/ai-history → { messages: [...], flaggedCount }

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiHistoryRepositoryProvider = Provider<AiHistoryRepository>((ref) {
  return AiHistoryRepository(dio: ref.watch(dioClientProvider));
});

/// Bola AI suhbat tarixi (childId bo'yicha) — ota-ona ko'rinishi.
final aiHistoryProvider =
    FutureProvider.family<AiHistory, String>((ref, childId) {
  return ref.read(aiHistoryRepositoryProvider).fetch(childId);
});

class AiHistoryRepository {
  AiHistoryRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<AiHistory> fetch(String childId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/ai-history',
      );
      final data = res.data ?? const {};
      final items = (data['messages'] as List<dynamic>?) ?? const [];
      return AiHistory(
        messages: items
            .whereType<Map<String, dynamic>>()
            .map(AiMessage.fromJson)
            .toList(),
        flaggedCount: (data['flaggedCount'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      debugPrint('AiHistoryRepository.fetch: ${e.response?.statusCode}');
      return const AiHistory(messages: [], flaggedCount: 0);
    }
  }
}

@immutable
class AiHistory {
  const AiHistory({required this.messages, required this.flaggedCount});
  final List<AiMessage> messages;
  final int flaggedCount;
}

@immutable
class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.flagged,
    required this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      text: json['text'] as String? ?? '',
      flagged: json['flagged'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  final String id;
  final String role;
  final String text;
  final bool flagged;
  final DateTime createdAt;

  bool get isUser => role == 'user';
}
