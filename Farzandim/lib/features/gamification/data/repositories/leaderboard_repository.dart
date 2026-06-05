// ─────────────────────────────────────────────────────────────────────
// LeaderboardRepository — XP reyting (GET /api/leaderboard) + avatar URL
// ─────────────────────────────────────────────────────────────────────

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(dio: ref.watch(dioClientProvider));
});

class LeaderboardRepository {
  LeaderboardRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Bir sahifa reyting. `period` = weekly|monthly|all.
  Future<LeaderboardPage> fetch({
    required String childId,
    required String period,
    String? region,
    required int page,
    int limit = 15,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/leaderboard',
      queryParameters: <String, dynamic>{
        'period': period,
        if (region != null && region.isNotEmpty) 'region': region,
        'page': page,
        'limit': limit,
        'childId': childId,
      },
    );
    return LeaderboardPage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Bola avatar proxy URL (@Public) — har qanday bola uchun ishlaydi.
  /// Rasm bo'lmasa 404 → UI harf/fallback ko'rsatadi.
  String avatarUrl(String childId) =>
      '${_dio.options.baseUrl}/children/$childId/avatar/image';
}
