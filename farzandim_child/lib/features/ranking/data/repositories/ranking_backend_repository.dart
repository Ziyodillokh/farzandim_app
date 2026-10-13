// ─────────────────────────────────────────────────────────────────────
// RankingBackendRepository — YAGONA DON reytingi
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt:
//   GET /api/leaderboard?period=all|daily|weekly|monthly&region=&page=&limit=
//                       &childId=
//
// Response:
//   { entries: [{ rank, childId, name, region, age, don, xp }],
//     total, hasMore, currentChild?, period }
//
// NEGA O'ZGARDI: bu ekran avval `/api/content/olympiads/ranking` dan OLIMPIADA
// ballarini olib, ularni "DON" deb ko'rsatardi. Ota-ona ilovasi esa yana boshqa
// manbalardan — panelda `ChildProfile.donBalance`, reytingda `xp`. Ya'ni bitta
// bola uch ekranda uch xil "DON" bilan ko'rinardi (210 / 260 / test bali).
// Endi hamma joyda YAGONA manba: `/api/leaderboard` → DON (donBalance).
//
// `region: 'me'` — bolaning o'z viloyati (klient o'z viloyatini mustaqil
// bilmaydi, u faqat javobdan keladi). Backend `me` ni server tomonda hal
// qiladi.
//
// MAXFIYLIK: boshqa bolalarning ismi shu yerda "Ism F." ko'rinishiga
// keltiriladi (`maskRankingName`) — backend niqoblashiga tayanilmaydi.
// `currentChild` — bola top-N ichida bo'lmasa ham o'zining REAL o'rni.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/data/ranking_name_privacy.dart';

final rankingBackendRepositoryProvider = Provider<RankingBackendRepository>((
  ref,
) {
  return RankingBackendRepository(dio: ref.watch(dioClientProvider));
});

class RankingResult {
  const RankingResult({
    required this.users,
    this.currentUserId,
    this.currentChild,
    this.currentChildRank,
  });
  final List<RankingUser> users;
  final String? currentUserId;

  /// Joriy bola (backend `currentChild`) — top-N ro'yxatda bo'lmasa ham.
  final RankingUser? currentChild;

  /// Joriy bolaning REAL o'rni (backend `currentChild.rank`).
  final int? currentChildRank;
}

class RankingBackendRepository {
  RankingBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// `range` — 'all', 'daily', 'weekly', 'monthly' (backend'da `period`).
  ///
  /// `region` — viloyat filtri. Backend SERVER tomonda filtrlaydi (top-N
  /// o'sha viloyat ichidan olinadi). `'me'` → bolaning o'z viloyati.
  /// `null` → global reyting.
  ///
  /// `childId` — "Siz" qatorini aniqlash uchun. Berilmasa hech kim joriy
  /// foydalanuvchi deb belgilanmaydi.
  Future<RankingResult> fetchRanking({
    required String? childId,
    String range = 'all',
    int limit = 50,
    String? region,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/leaderboard',
        queryParameters: <String, dynamic>{
          'period': range,
          'page': 1,
          'limit': limit,
          if (region != null && region.isNotEmpty) 'region': region,
          if (childId != null && childId.isNotEmpty) 'childId': childId,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      final entries = (data['entries'] as List<dynamic>?) ?? const [];
      final users = entries
          .whereType<Map<String, dynamic>>()
          .map((raw) => _toRankingUser(raw, range, childId))
          .toList();
      // Joriy bola (top-N ichida bo'lmasa ham) — faqat o'z childId'si bo'lsa.
      final meRaw = data['currentChild'];
      final meMap = meRaw is Map<String, dynamic> ? meRaw : null;
      final me = meMap == null ? null : _toRankingUser(meMap, range, childId);
      final isMeValid = me != null && me.isCurrentUser;
      return RankingResult(
        users: users,
        currentUserId: childId,
        currentChild: isMeValid ? me : null,
        currentChildRank: isMeValid ? (meMap?['rank'] as num?)?.toInt() : null,
      );
    } on DioException catch (e) {
      debugPrint('RankingBackend.fetch: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  RankingUser _toRankingUser(
    Map<String, dynamic> raw,
    String range,
    String? childId,
  ) {
    final don = (raw['don'] as num?)?.toInt() ?? 0;
    final id = (raw['childId'] as String?) ?? '';
    final isMe = id.isNotEmpty && id == childId;
    final rawName = (raw['name'] as String?) ?? '';
    // Boshqa bolalar — faqat "Ism F." (to'liq ism ko'rsatilmaydi). O'z ismi
    // o'zgarishsiz (bo'sh bo'lsa umumiy zaxira nom).
    final name = isMe
        ? (rawName.trim().isEmpty ? 'common.fallbackChildName'.tr() : rawName)
        : (maskRankingName(rawName) ?? 'ranking.anonymousChild'.tr());
    // Bir range uchun fetch qilinadi, lekin RankingUser barcha range scorlarini
    // saqlaydi — qolganlarini 0 qilamiz, UI tab'ga qarab tegishlisini
    // ko'rsatadi.
    return RankingUser(
      id: id,
      name: name,
      age: (raw['age'] as num?)?.toInt() ?? 8,
      gender: raw['gender'] as String?,
      region: (raw['region'] as String?) ?? "O'zbekiston",
      totalScore: range == 'all' ? don : 0,
      weeklyScore: range == 'weekly' ? don : 0,
      monthlyScore: range == 'monthly' ? don : 0,
      dailyScore: range == 'daily' ? don : 0,
      streakDays: 0,
      badgeCount: 0,
      previousRank: (raw['rank'] as num?)?.toInt() ?? 0,
      avatarColor: _avatarColorFor(id),
      isCurrentUser: isMe,
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
