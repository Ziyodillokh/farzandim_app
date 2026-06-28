// ─────────────────────────────────────────────────────────────────────
// BackendRoutineRepository — Backend Routines API (Sprint 4.4.4)
// ─────────────────────────────────────────────────────────────────────
//
// **Eslatma:** Backend `Routine` ↔ Frontend `Schedule` (semantik teng —
// kun rejasi). Backend `Schedule` (BLOCK/ALLOW app cheklash) hozircha
// Frontend UI'da yo'q.
//
// Backend kontract:
//   GET    /api/children/:childId/routines       → {routines, count}
//   GET    /api/children/:childId/routines/today → {today, current, next, serverTime}
//   POST   /api/children/:childId/routines       body: Routine payload
//   GET    /api/routines/:id                     → Routine
//   PUT    /api/routines/:id                     body: partial
//   DELETE /api/routines/:id
//   WS     routine:created/updated/deleted       → child room

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendRoutineRepositoryProvider = Provider<BackendRoutineRepository>((
  ref,
) {
  final auth = ref.watch(backendAuthProvider);
  final currentUserId = auth is AuthAuthenticated ? auth.user.id : '';
  return BackendRoutineRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
    currentUserId: currentUserId,
  );
});

class BackendRoutineRepository {
  BackendRoutineRepository({
    required Dio dio,
    required SocketClient socketClient,
    required String currentUserId,
  }) : _dio = dio,
       _socketClient = socketClient,
       _currentUserId = currentUserId;

  final Dio _dio;
  final SocketClient _socketClient;
  final String _currentUserId;

  /// Bola uchun barcha routine'lar (kun rejalari).
  Future<List<Schedule>> getRoutines(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/routines',
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['routines'] as List<dynamic>? ?? const [];
      return list
          .map(
            (e) => Schedule.fromBackendJson(
              e as Map<String, dynamic>,
              parentUid: _currentUserId,
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint('BackendRoutineRepository.getRoutines: $e');
      return const [];
    }
  }

  /// Yangi routine yaratish.
  Future<Schedule?> createRoutine({
    required String childId,
    required Schedule routine,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/routines',
        data: routine.toBackendJson(),
      );
      final data = response.data;
      if (data == null) return null;
      return Schedule.fromBackendJson(data, parentUid: _currentUserId);
    } on DioException catch (e) {
      debugPrint('BackendRoutineRepository.createRoutine: $e');
      rethrow;
    }
  }

  /// Routine'ni yangilash (partial).
  Future<Schedule?> updateRoutine({
    required String routineId,
    required Schedule routine,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/routines/$routineId',
        data: routine.toBackendJson(),
      );
      final data = response.data;
      if (data == null) return null;
      return Schedule.fromBackendJson(data, parentUid: _currentUserId);
    } on DioException catch (e) {
      debugPrint('BackendRoutineRepository.updateRoutine: $e');
      rethrow;
    }
  }

  /// Routine'ni o'chirish.
  Future<bool> deleteRoutine(String routineId) async {
    try {
      await _dio.delete<void>('/routines/$routineId');
      return true;
    } on DioException {
      return false;
    }
  }

  /// WS event stream'lari (created/updated/deleted) — cache invalidate
  /// uchun.
  Stream<dynamic> createdStream() =>
      _socketClient.eventStream('routine:created');
  Stream<dynamic> updatedStream() =>
      _socketClient.eventStream('routine:updated');
  Stream<dynamic> deletedStream() =>
      _socketClient.eventStream('routine:deleted');
}
