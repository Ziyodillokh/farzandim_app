// ─────────────────────────────────────────────────────────────────────
// BackendNotificationRepository — Backend Notifications API (Sprint 4.4.6)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/children/:childId/notifications  → {notifications, count,
//                                                 unreadCount}
//   POST /api/children/:childId/notifications  body: {type, title, body, data?}
//   PUT /api/notifications/:id/read
//   PUT /api/children/:childId/notifications/read-all
//   DELETE /api/notifications/:id
//   WS notification:created/read/read-all/deleted → child room
//
// Bola notifications — parent monitoring uchun ham (history view).
// Frontend notification types: ACHIEVEMENT, CONTEST, SCHEDULE,
// PARENT_REQUEST, VOICE, GEO_ZONE, SYSTEM.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendNotificationRepositoryProvider =
    Provider<BackendNotificationRepository>((ref) {
  return BackendNotificationRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

class BackendNotificationRepository {
  BackendNotificationRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  /// Bola notifications ro'yxati (parent monitoring history).
  Future<List<Map<String, dynamic>>> getNotifications({
    required String childId,
    String? type,
    bool? isRead,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/notifications',
        queryParameters: {
          if (type != null) 'type': type,
          if (isRead != null) 'isRead': isRead,
          'limit': limit,
        },
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['notifications'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('BackendNotificationRepository.getNotifications: $e');
      return const [];
    }
  }

  /// Notification yaratish (parent bola'ga yuborish — masalan
  /// PARENT_REQUEST tipida).
  Future<Map<String, dynamic>?> createNotification({
    required String childId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/notifications',
        data: {
          'type': type,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      await _dio.put<void>('/notifications/$notificationId/read');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> markAllAsRead(String childId) async {
    try {
      await _dio
          .put<void>('/children/$childId/notifications/read-all');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _dio.delete<void>('/notifications/$notificationId');
      return true;
    } on DioException {
      return false;
    }
  }

  // WS streams
  Stream<dynamic> createdStream() =>
      _socketClient.eventStream('notification:created');
  Stream<dynamic> readStream() =>
      _socketClient.eventStream('notification:read');
  Stream<dynamic> readAllStream() =>
      _socketClient.eventStream('notification:read-all');
  Stream<dynamic> deletedStream() =>
      _socketClient.eventStream('notification:deleted');
}
