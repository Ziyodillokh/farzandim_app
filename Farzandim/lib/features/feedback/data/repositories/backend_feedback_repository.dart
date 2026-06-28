// Backend feedback API — bola emoji + matn yuboradi, parent o'qiydi.

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendFeedbackRepositoryProvider = Provider<BackendFeedbackRepository>((
  ref,
) {
  return BackendFeedbackRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendFeedbackRepository {
  BackendFeedbackRepository({
    required Dio dio,
    required SocketClient socketClient,
  }) : _dio = dio,
       _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Bola feedback ro'yxati (parent inbox).
  Future<List<Map<String, dynamic>>> getFeedback({
    required String childId,
    bool? isRead,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/feedback',
        queryParameters: {if (isRead != null) 'isRead': isRead, 'limit': limit},
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['feedback'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendFeedbackRepository.getFeedback: $e');
      return const [];
    }
  }

  /// Feedback'ni o'qilgan deb belgilaydi.
  Future<bool> markAsRead(String feedbackId) async {
    try {
      await _dio.put<void>('/feedback/$feedbackId/read');
      return true;
    } on DioException {
      return false;
    }
  }

  /// WS `feedback:received` — bola yangi emoji yubordi (parent user room).
  Stream<dynamic> receivedStream() =>
      _socketClient.eventStream('feedback:received');
}
