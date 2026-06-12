// ─────────────────────────────────────────────────────────────────────
// BackendGamificationRepository — Backend Gamification API (Sprint 4.4.6)
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/children/:childId/profile     → ChildProfile
//   POST /api/children/:childId/xp-events  → {event, profile}
//   GET /api/children/:childId/xp-events   → history
//   GET /api/children/:childId/achievements
//   WS profile:updated → child room (XP/Level o'zgarsa)
//
// ChildProfile: xp, donBalance, level, status, streakDays, achievements[]
// Status mapping (Backend):
//   < 300 → Boshlovchi, < 900 → Izlanuvchi, < 2000 → Bilimdon,
//   < 5000 → Lider, >= 5000 → Mentor
// Level formula: floor(sqrt(xp) / 5) + 1

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backendGamificationRepositoryProvider =
    Provider<BackendGamificationRepository>((ref) {
  return BackendGamificationRepository(
    dio: ref.watch(dioClientProvider),
    socketClient: ref.watch(socketClientProvider),
  );
});

/// Bola gamifikatsiya profili — XP, DON, Level, Status, Streak.
@immutable
class ChildProfile {
  const ChildProfile({
    required this.xp,
    required this.donBalance,
    required this.level,
    required this.status,
    required this.streakDays,
    required this.lastActivityDate,
    required this.achievements,
  });

  factory ChildProfile.fromBackendJson(Map<String, dynamic> json) {
    return ChildProfile(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      donBalance: (json['donBalance'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      status: (json['status'] as String?) ?? 'Boshlovchi',
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      lastActivityDate: json['lastActivityDate'] != null
          ? DateTime.tryParse(json['lastActivityDate'] as String)
              ?.toLocal()
          : null,
      achievements:
          (json['achievements'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>(),
    );
  }

  factory ChildProfile.empty() => const ChildProfile(
        xp: 0,
        donBalance: 0,
        level: 1,
        status: 'Boshlovchi',
        streakDays: 0,
        lastActivityDate: null,
        achievements: [],
      );

  final int xp;
  final int donBalance;
  final int level;
  final String status;
  final int streakDays;
  final DateTime? lastActivityDate;
  final List<Map<String, dynamic>> achievements;
}

class BackendGamificationRepository {
  BackendGamificationRepository({
    required Dio dio,
    required SocketClient socketClient,
  })  : _dio = dio,
        _socketClient = socketClient;

  final Dio _dio;
  final SocketClient _socketClient;

  Future<ChildProfile?> getProfile(String childId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/profile',
      );
      final data = response.data;
      if (data == null) return null;
      return ChildProfile.fromBackendJson(data);
    } on DioException catch (e) {
      debugPrint('BackendGamificationRepository.getProfile: $e');
      return null;
    }
  }

  /// XP event yaratish (parent qo'lda XP qo'shishi mumkin, masalan
  /// "topshiriqni bajardi"). Bola ham yozadi (achievement uchun).
  Future<Map<String, dynamic>?> addXpEvent({
    required String childId,
    required String type,
    required int xpDelta,
    int donDelta = 0,
    String? relatedId,
    Map<String, dynamic>? source,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/children/$childId/xp-events',
        data: {
          'type': type,
          'xpDelta': xpDelta,
          'donDelta': donDelta,
          if (relatedId != null) 'relatedId': relatedId,
          if (source != null) 'source': source,
        },
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getXpEvents({
    required String childId,
    String? type,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/children/$childId/xp-events',
        queryParameters: {
          if (type != null) 'type': type,
          'limit': limit,
        },
      );
      final data = response.data;
      if (data == null) return const [];
      final list = data['events'] as List<dynamic>? ?? const [];
      return list.cast<Map<String, dynamic>>();
    } on DioException {
      return const [];
    }
  }

  /// WS `profile:updated` — XP yangilanganda (child room).
  Stream<dynamic> profileUpdatedStream() =>
      _socketClient.eventStream('profile:updated');
}
