// ─────────────────────────────────────────────────────────────────────
// VideoEngagementRepository — ko'rish tarixi + yoqtirilganlar (backend)
// ─────────────────────────────────────────────────────────────────────
//
// Backend (consumer-content):
//   POST   /content/videos/:id/history   → tarixga yozadi (upsert)
//   GET    /content/history/videos       → { items: [video + viewedAt] }
//   PUT    /content/videos/:id/favorite  → yoqtirilganlarga qo'shadi
//   DELETE /content/videos/:id/favorite  → olib tashlaydi
//   GET    /content/favorites/videos     → { items: [video + favoritedAt] }
//   GET    /content/favorites/ids        → { ids: [...] }
//
// List'lar ContentCache orqali offline keshlanadi (oxirgi ma'lum ro'yxat).
// Video shakli feed bilan bir xil (videoFromApiJson).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/cache/content_cache.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/video_api_mapper.dart';

final videoEngagementRepositoryProvider = Provider<VideoEngagementRepository>((
  ref,
) {
  return VideoEngagementRepository(dio: ref.watch(dioClientProvider));
});

/// Video + qachon (ko'rilgan / yoqtirilgan vaqti). Sahifalar kun bo'yicha
/// guruhlash uchun shu vaqtdan foydalanadi.
class VideoEngagementEntry {
  const VideoEngagementEntry({required this.video, required this.at});

  final VideoModel video;
  final DateTime at;
}

class VideoEngagementRepository {
  VideoEngagementRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _historyCacheKey = 'video_history';
  static const String _favoritesCacheKey = 'video_favorites';

  /// Video ochilganda tarixga yozadi (fire-and-forget — xatoni yutadi).
  Future<void> recordHistory(String videoId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/content/videos/$videoId/history');
    } on DioException catch (e) {
      debugPrint('Engagement.recordHistory: ${e.message}');
    }
  }

  /// Yoqtirilganlarga qo'shadi (fire-and-forget).
  Future<void> addFavorite(String videoId) async {
    try {
      await _dio.put<Map<String, dynamic>>('/content/videos/$videoId/favorite');
    } on DioException catch (e) {
      debugPrint('Engagement.addFavorite: ${e.message}');
    }
  }

  /// Yoqtirilganlardan olib tashlaydi (fire-and-forget).
  Future<void> removeFavorite(String videoId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/content/videos/$videoId/favorite',
      );
    } on DioException catch (e) {
      debugPrint('Engagement.removeFavorite: ${e.message}');
    }
  }

  /// Yoqtirilgan video ID'lari (feed ♡ holatini backend bilan sinxronlash).
  /// Xato/offline → `null` (lokal holat saqlanadi).
  Future<List<String>?> fetchFavoriteIds() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/content/favorites/ids',
      );
      final ids = (res.data?['ids'] as List<dynamic>?) ?? const [];
      return ids.map((e) => e.toString()).toList(growable: false);
    } on DioException catch (e) {
      debugPrint('Engagement.fetchFavoriteIds: ${e.message}');
      return null;
    }
  }

  /// Ko'rish tarixi (yangi → eski). Offline → oxirgi kesh.
  Future<List<VideoEngagementEntry>> fetchHistory() =>
      _fetchList('/content/history/videos', 'viewedAt', _historyCacheKey);

  /// Yoqtirilgan videolar (yangi → eski). Offline → oxirgi kesh.
  Future<List<VideoEngagementEntry>> fetchFavorites() => _fetchList(
    '/content/favorites/videos',
    'favoritedAt',
    _favoritesCacheKey,
  );

  Future<List<VideoEngagementEntry>> _fetchList(
    String path,
    String tsField,
    String cacheKey,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      final items = (res.data?['items'] as List<dynamic>?) ?? const [];
      await ContentCache.save(cacheKey, items);
      return _parse(items, tsField);
    } on DioException catch (e) {
      debugPrint('Engagement._fetchList $path: ${e.message}');
      // Offline/xato — oxirgi keshdan ko'rsatamiz (bo'lsa).
      final cached = await ContentCache.read(cacheKey);
      if (cached != null) return _parse(cached, tsField);
      rethrow;
    }
  }

  List<VideoEngagementEntry> _parse(List<dynamic> items, String tsField) {
    return items
        .whereType<Map<String, dynamic>>()
        .map((raw) {
          return VideoEngagementEntry(
            video: videoFromApiJson(raw),
            at:
                DateTime.tryParse(raw[tsField]?.toString() ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .toList(growable: false);
  }
}
