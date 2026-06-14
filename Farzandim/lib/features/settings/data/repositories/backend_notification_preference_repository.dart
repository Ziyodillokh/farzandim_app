// ─────────────────────────────────────────────────────────────────────
// BackendNotificationPreferenceRepository — eslatma sozlamalari (#66/#67/#77)
// ─────────────────────────────────────────────────────────────────────
//
// GET/PUT /children/:childId/notification-preferences. Ota-ona bola uchun
// dars/sport/kontent eslatmalarini yoqadi/o'chiradi va tinch soatlarni belgilaydi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendNotificationPreferenceRepositoryProvider =
    Provider<BackendNotificationPreferenceRepository>((ref) {
  return BackendNotificationPreferenceRepository(
    dio: ref.watch(dioClientProvider),
  );
});

class BackendNotificationPreferenceRepository {
  BackendNotificationPreferenceRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<NotificationPreferences> get(String childId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/children/$childId/notification-preferences',
    );
    return NotificationPreferences.fromJson(res.data ?? const {});
  }

  /// Eslatma turini (toggle) yangilash — faqat berilgani yuboriladi.
  Future<NotificationPreferences> update(
    String childId, {
    bool? studyNudge,
    bool? healthNudge,
    bool? contentReminder,
  }) async {
    final body = <String, dynamic>{
      if (studyNudge != null) 'studyNudge': studyNudge,
      if (healthNudge != null) 'healthNudge': healthNudge,
      if (contentReminder != null) 'contentReminder': contentReminder,
    };
    return _put(childId, body);
  }

  /// Tinch soatlarni belgilash yoki tozalash (`null` = tozalash).
  Future<NotificationPreferences> setQuietHours(
    String childId, {
    required String? from,
    required String? to,
  }) {
    return _put(childId, {'quietFrom': from, 'quietTo': to});
  }

  Future<NotificationPreferences> _put(
    String childId,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/children/$childId/notification-preferences',
      data: body,
    );
    return NotificationPreferences.fromJson(res.data ?? const {});
  }
}

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.studyNudge,
    required this.healthNudge,
    required this.contentReminder,
    this.quietFrom,
    this.quietTo,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      studyNudge: json['studyNudge'] as bool? ?? true,
      healthNudge: json['healthNudge'] as bool? ?? true,
      contentReminder: json['contentReminder'] as bool? ?? true,
      quietFrom: json['quietFrom'] as String?,
      quietTo: json['quietTo'] as String?,
    );
  }

  final bool studyNudge;
  final bool healthNudge;
  final bool contentReminder;

  /// Tinch soat oynasi "HH:MM" (null = belgilanmagan).
  final String? quietFrom;
  final String? quietTo;

  bool get hasQuietHours => quietFrom != null && quietTo != null;
}
