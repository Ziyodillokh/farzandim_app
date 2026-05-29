// ─────────────────────────────────────────────────────────────────────
// RankingBackendRepository — Sprint 5.7c
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/content/olympiads/ranking?range=all|daily|weekly|monthly&limit=
//
// Response:
//   { items: [{ position, childId, name, age, region, totalScore,
//               attemptCount, isCurrentUser }],
//     currentUserId, currentUser?, range }
//
// Aggregation: OlympiadAttempt.status='finished' bo'yicha groupBy childId,
// score yig'indisi. Real backend (Sprint 5.4 Olympiad attempts ustida).

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';

final rankingBackendRepositoryProvider = Provider<RankingBackendRepository>((ref) {
  return RankingBackendRepository(dio: ref.watch(dioClientProvider));
});

class RankingResult {
  const RankingResult({required this.users, this.currentUserId});
  final List<RankingUser> users;
  final String? currentUserId;
}

class RankingBackendRepository {
  RankingBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// `range` — 'all', 'daily', 'weekly', 'monthly'.
  Future<RankingResult> fetchRanking({String range = 'all', int limit = 50}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/olympiads/ranking',
        queryParameters: {'range': range, 'limit': limit},
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      final currentUserId = response.data?['currentUserId'] as String?;
      final users = items
          .whereType<Map<String, dynamic>>()
          .map((raw) => _toRankingUser(raw, range))
          .toList();
      return RankingResult(users: users, currentUserId: currentUserId);
    } on DioException catch (e) {
      debugPrint('RankingBackend.fetch: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  RankingUser _toRankingUser(Map<String, dynamic> raw, String range) {
    final score = (raw['totalScore'] as num?)?.toInt() ?? 0;
    final isCurrent = raw['isCurrentUser'] == true;
    final id = (raw['childId'] as String?) ?? '';
    // Bir range uchun fetch qilinadi, lekin RankingUser barcha range scorlarini
    // saqlaydi — qolganlarini 0 qilamiz, UI tab'ga qarab tegishlisini ko'rsatadi.
    return RankingUser(
      id: id,
      name: (raw['name'] as String?) ?? '—',
      age: (raw['age'] as num?)?.toInt() ?? 8,
      region: (raw['region'] as String?) ?? "O'zbekiston",
      totalScore: range == 'all' ? score : 0,
      weeklyScore: range == 'weekly' ? score : 0,
      monthlyScore: range == 'monthly' ? score : 0,
      dailyScore: range == 'daily' ? score : 0,
      streakDays: 0,
      badgeCount: (raw['attemptCount'] as num?)?.toInt() ?? 0,
      previousRank: (raw['position'] as num?)?.toInt() ?? 0,
      avatarColor: _avatarColorFor(id),
      isCurrentUser: isCurrent,
    );
  }

  Color _avatarColorFor(String id) {
    if (id.isEmpty) return AppColors.catIndigo;
    int hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    const palette = <Color>[
      AppColors.catIndigo,
      AppColors.catPink,
      AppColors.warning,
      AppColors.catEmerald,
      AppColors.catTeal,
      AppColors.catPurple,
      AppColors.catOrangeDark,
    ];
    return palette[hash % palette.length];
  }
}
