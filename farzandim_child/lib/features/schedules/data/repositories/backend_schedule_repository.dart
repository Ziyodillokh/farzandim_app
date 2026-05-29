// ─────────────────────────────────────────────────────────────────────
// BackendScheduleRepository — Child App App Restrictions (Sprint 4.4.9.3)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Child JWT bilan o'qish):
//   GET /api/children/:childId/schedules → {schedules, count}
//
// **Eslatma:** Backend `Schedule` = app cheklash (BLOCK/ALLOW + HH:MM
// + daysOfWeek). Frontend `Schedule` (=Routine) bilan adashtirmang!
// Bu repository app restrictions uchun.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendScheduleRepositoryProvider =
    Provider<BackendScheduleRepository>((ref) {
  return BackendScheduleRepository(dio: ref.watch(dioClientProvider));
});

/// Backend Schedule = app cheklash policy.
@immutable
class AppSchedulePolicy {
  const AppSchedulePolicy({
    required this.id,
    required this.name,
    required this.startTime, // "HH:MM"
    required this.endTime,
    required this.daysOfWeek, // ISO 1..7
    required this.action, // BLOCK | ALLOW
    required this.isActive,
  });

  factory AppSchedulePolicy.fromBackendJson(Map<String, dynamic> json) {
    return AppSchedulePolicy(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      startTime: (json['startTime'] as String?) ?? '00:00',
      endTime: (json['endTime'] as String?) ?? '23:59',
      daysOfWeek: ((json['daysOfWeek'] as List?) ?? const [])
          .map((d) => (d as num).toInt())
          .toList(),
      action: (json['action'] as String?) ?? 'BLOCK',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final List<int> daysOfWeek;
  final String action;
  final bool isActive;
}

class BackendScheduleRepository {
  BackendScheduleRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Bola uchun app schedule policy'lar (BLOCK/ALLOW).
  Future<List<AppSchedulePolicy>> getSchedules(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/schedules',
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['schedules'] as List<dynamic>? ?? const [];
      return list
          .map((e) =>
              AppSchedulePolicy.fromBackendJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendScheduleRepository.getSchedules: $e');
      return const [];
    }
  }
}
