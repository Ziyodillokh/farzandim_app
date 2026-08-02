// ─────────────────────────────────────────────────────────────────────
// BackendRoutineRepository — Child App Backend Routines (Sprint 4.4.9.3)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Child JWT bilan o'qish):
//   GET /api/children/:childId/routines       → {routines, count}
//   GET /api/children/:childId/routines/today → {today, current, next}
//
// Bola Routine'larni faqat **o'qiydi** (Parent yozadi). Dashboard
// ScheduleMiniCard `/today` endpoint'idan optimized data oladi.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendRoutineRepositoryProvider =
    Provider<BackendRoutineRepository>((ref) {
  return BackendRoutineRepository(dio: ref.watch(dioClientProvider));
});

/// Bugungi kun rejasi — Backend `/today` endpoint qaytaradi.
@immutable
class TodayRoutines {
  const TodayRoutines({
    required this.today,
    this.current,
    this.next,
  });

  factory TodayRoutines.fromBackendJson(Map<String, dynamic> json) {
    final todayList = (json['today'] as List?) ?? const [];
    final currentJson = json['current'] as Map<String, dynamic>?;
    final nextJson = json['next'] as Map<String, dynamic>?;

    return TodayRoutines(
      today: todayList
          .map((e) => Schedule.fromBackendJson(e as Map<String, dynamic>))
          .toList(),
      current: currentJson != null
          ? Schedule.fromBackendJson(currentJson)
          : null,
      next: nextJson != null ? Schedule.fromBackendJson(nextJson) : null,
    );
  }

  /// Bugun aktiv rejalar (weekday filter Backend'da).
  final List<Schedule> today;

  /// Hozir aktiv reja (current time ichida).
  final Schedule? current;

  /// Kelayotgan eng yaqin reja.
  final Schedule? next;
}

class BackendRoutineRepository {
  BackendRoutineRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Bola uchun barcha rejalar.
  ///
  /// XAVFSIZLIK (fail-closed): tarmoq xatosida `null` — "BILMAYMAN", "reja
  /// yo'q" EMAS. Qarang: `BackendAppLimitRepository.getLimits` izohi.
  Future<List<Schedule>?> getRoutines(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/routines',
      );
      final data = response.data;
      if (data == null) return null;
      final list = data['routines'] as List<dynamic>? ?? const [];
      return list
          .map((e) =>
              Schedule.fromBackendJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendRoutineRepository.getRoutines: $e');
      return null;
    }
  }

  /// Bugungi kun rejasi (Tashkent UTC+5 serverda) + current/next.
  /// Dashboard ScheduleMiniCard widget shu yerdan o'qiydi.
  Future<TodayRoutines?> getToday(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/routines/today',
      );
      final data = response.data;
      if (data == null) return null;
      return TodayRoutines.fromBackendJson(data);
    } on DioException catch (e) {
      debugPrint('BackendRoutineRepository.getToday: $e');
      return null;
    }
  }
}
