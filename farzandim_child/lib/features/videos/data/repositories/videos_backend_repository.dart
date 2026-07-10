// ─────────────────────────────────────────────────────────────────────
// VideosBackendRepository — Sprint 5.7b
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Sprint 5.7a):
//   GET /api/content/videos?page=&limit=
//     → { items: [{ id, title, description, url, thumbnail, durationSec,
//                   ageFrom, ageTo, category, planRequired, level, featured,
//                   views, likes, createdAt }],
//         pagination: { page, totalPages, total, limit } }
//
//   POST /api/content/videos/:id/view  → views++
//   POST /api/content/videos/:id/like  → likes++
//
// Filter logikasi backend tomonida:
//   - status='approved' faqat
//   - child.age ageFrom..ageTo oraliqida
//   - planRequired bola ota-onasining payment'lariga qarab
//
// Bola muvaffaqiyatli pair qilingan bo'lishi va Bearer JWT mavjud
// bo'lishi shart (qarang `dio_client.dart` AuthInterceptor).

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/cache/content_cache.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/video_api_mapper.dart';

final videosBackendRepositoryProvider = Provider<VideosBackendRepository>((
  ref,
) {
  return VideosBackendRepository(dio: ref.watch(dioClientProvider));
});

class VideosBackendRepository {
  VideosBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<List<VideoModel>> fetchVideos({int page = 1, int limit = 50}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/videos',
        queryParameters: {'page': page, 'limit': limit},
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      // PERF/offline: birinchi sahifani lokal cache'ga yozamiz — keyingi
      // ochilishda darhol ko'rsatiladi (stale-while-revalidate).
      if (page == 1) {
        await ContentCache.save('videos', items);
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(videoFromApiJson)
          .toList(growable: false);
    } on DioException catch (e) {
      debugPrint(
        'VideosBackend.fetchVideos: ${e.response?.statusCode} ${e.message}',
      );
      rethrow;
    }
  }

  /// Lokal cache'dagi videolar (yo'q bo'lsa bo'sh ro'yxat). Network kutmaydi —
  /// cold start'da darhol qaytadi, UI'ni bir zumda to'ldiradi.
  Future<List<VideoModel>> cachedVideos() async {
    final items = await ContentCache.read('videos');
    if (items == null) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(videoFromApiJson)
        .toList(growable: false);
  }

  /// Bola video boshlaganda view counter++ (fire-and-forget).
  Future<void> markViewed(String videoId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/content/videos/$videoId/view');
    } on DioException catch (e) {
      debugPrint('VideosBackend.markViewed: ${e.message}');
    }
  }

  /// Player aniqlagan haqiqiy davomiylikni backend'ga yuboradi (fire-and-
  /// forget). Backend faqat duration hozir noma'lum (0) bo'lsa yozadi —
  /// link orqali qo'shilgan YouTube videolari ro'yxatda to'g'ri vaqt bilan
  /// ko'rinishi uchun.
  Future<void> reportDuration(String videoId, int durationSec) async {
    if (durationSec <= 0) return;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/content/videos/$videoId/duration',
        data: {'durationSec': durationSec},
      );
    } on DioException catch (e) {
      debugPrint('VideosBackend.reportDuration: ${e.message}');
    }
  }

  /// Like tugmasi bosilganda likes counter++.
  Future<int?> like(String videoId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/content/videos/$videoId/like',
      );
      return (response.data?['likes'] as num?)?.toInt();
    } on DioException catch (e) {
      debugPrint('VideosBackend.like: ${e.message}');
      return null;
    }
  }
}
