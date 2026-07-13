// ─────────────────────────────────────────────────────────────────────
// ArticlesBackendRepository — maqolalar API (#48)
// ─────────────────────────────────────────────────────────────────────
//
//   GET  /api/content/articles?page=&limit=  → { items, pagination }
//   POST /api/content/articles/:id/read       → views++

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';

final articlesBackendRepositoryProvider =
    Provider<ArticlesBackendRepository>((ref) {
  return ArticlesBackendRepository(dio: ref.watch(dioClientProvider));
});

class ArticlesBackendRepository {
  ArticlesBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<List<ArticleModel>> fetchArticles({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/articles',
        queryParameters: {'page': page, 'limit': limit},
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(_toModel)
          .toList(growable: false);
    } on DioException catch (e) {
      debugPrint(
        'ArticlesBackend.fetchArticles: ${e.response?.statusCode} ${e.message}',
      );
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post<Map<String, dynamic>>('/content/articles/$id/read');
    } on DioException catch (e) {
      debugPrint('ArticlesBackend.markRead: ${e.message}');
    }
  }

  /// Maqola yoqtirildi → likes++ (backend global hisoblagichi). Yangi
  /// likes sonini qaytaradi (UI darhol yangilashi uchun), xato'da null.
  Future<int?> like(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/content/articles/$id/like',
      );
      return (res.data?['likes'] as num?)?.toInt();
    } on DioException catch (e) {
      debugPrint('ArticlesBackend.like: ${e.message}');
      return null;
    }
  }

  ArticleModel _toModel(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    return ArticleModel(
      id: id,
      title: (raw['title'] as String?) ?? '—',
      body: (raw['body'] as String?) ?? '',
      coverUrl: EnvConfig.resolveMediaUrl((raw['coverUrl'] as String?) ?? ''),
      category: (raw['category'] as String?) ?? '',
      ageFrom: (raw['ageFrom'] as num?)?.toInt() ?? 0,
      ageTo: (raw['ageTo'] as num?)?.toInt() ?? 18,
      views: (raw['views'] as num?)?.toInt() ?? 0,
      likes: (raw['likes'] as num?)?.toInt() ?? 0,
      coverColor: _coverColorFor(id),
    );
  }

  Color _coverColorFor(String id) {
    if (id.isEmpty) return AppColors.catLavenderDark;
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    const palette = <Color>[
      AppColors.catLavenderDark,
      AppColors.catBlue,
      AppColors.catMint,
      AppColors.catLavender,
      AppColors.catGreen,
      AppColors.catPinkVibrant,
    ];
    return palette[hash % palette.length];
  }
}
