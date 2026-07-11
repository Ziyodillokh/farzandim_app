// ─────────────────────────────────────────────────────────────────────
// BackendNotificationRepository — Child App Notifications (Sprint 4.4.9.5)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Child JWT bilan):
//   GET /api/children/:childId/notifications → {notifications, count, unreadCount}
//   PUT /api/notifications/:id/read
//   PUT /api/children/:childId/notifications/read-all
//   DELETE /api/notifications/:id
//
// Bola notifications — parent yuborgan (PARENT_REQUEST, ACHIEVEMENT,
// CONTEST), system messages, schedule reminders.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendNotificationRepositoryProvider =
    Provider<BackendNotificationRepository>((ref) {
      return BackendNotificationRepository(dio: ref.watch(dioClientProvider));
    });

class BackendNotificationRepository {
  BackendNotificationRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<({List<AppNotification> items, int unreadCount})> getNotifications({
    required String childId,
    bool? isRead,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/notifications',
        queryParameters: {if (isRead != null) 'isRead': isRead, 'limit': limit},
      );
      final data = response.data;
      if (data == null) {
        return (items: <AppNotification>[], unreadCount: 0);
      }
      final list = data['notifications'] as List<dynamic>? ?? const [];
      final items = list
          .map(
            (e) => AppNotification.fromBackendJson(e as Map<String, dynamic>),
          )
          .toList();
      final unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
      return (items: items, unreadCount: unread);
    } on DioException catch (e) {
      debugPrint('BackendNotificationRepository.getNotifications: $e');
      return (items: <AppNotification>[], unreadCount: 0);
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
      await _dio.put<void>('/children/$childId/notifications/read-all');
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
}
