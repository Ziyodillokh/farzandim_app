// ─────────────────────────────────────────────────────────────────────
// AudiobooksBackendRepository — Sprint 5.7b
// ─────────────────────────────────────────────────────────────────────
//
// Backend kontrakt (Sprint 5.7a):
//   GET /api/content/audiobooks?page=&limit=
//     → { items: [{ id, title, author, description, audioUrl, thumbnail,
//                   durationSec, partsCount, ageFrom, ageTo, category,
//                   planRequired, listens, createdAt }],
//         pagination: {...} }
//
//   POST /api/content/audiobooks/:id/play  → listens++
//
// Filter logikasi backend tomonida (status='approved', age, plan).

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';

final audiobooksBackendRepositoryProvider =
    Provider<AudiobooksBackendRepository>((ref) {
  return AudiobooksBackendRepository(dio: ref.watch(dioClientProvider));
});

class AudiobooksBackendRepository {
  AudiobooksBackendRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<List<AudiobookModel>> fetchAudiobooks({int page = 1, int limit = 50}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/content/audiobooks',
        queryParameters: {'page': page, 'limit': limit},
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(_toAudiobookModel)
          .toList(growable: false);
    } on DioException catch (e) {
      debugPrint('AudiobooksBackend.fetch: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  /// Bola tinglashni boshlaganda listens counter++.
  Future<void> markPlayed(String audiobookId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/content/audiobooks/$audiobookId/play');
    } on DioException catch (e) {
      debugPrint('AudiobooksBackend.markPlayed: ${e.message}');
    }
  }

  /// Player aniqlagan haqiqiy davomiylik (backend faqat 0/noma'lum bo'lsa
  /// yozadi). Admin upload paytida duration kiritmaydi.
  Future<void> reportDuration(String audiobookId, int durationSec) async {
    if (durationSec <= 0) return;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/content/audiobooks/$audiobookId/duration',
        data: {'durationSec': durationSec},
      );
    } on DioException catch (e) {
      debugPrint('AudiobooksBackend.reportDuration: ${e.message}');
    }
  }

  AudiobookModel _toAudiobookModel(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    final durationSec = (raw['durationSec'] as num?)?.toInt() ?? 0;
    final ageFrom = (raw['ageFrom'] as num?)?.toInt() ?? 0;
    final ageTo = (raw['ageTo'] as num?)?.toInt() ?? 18;
    final category = (raw['category'] as String?)?.trim();
    return AudiobookModel(
      id: id,
      title: (raw['title'] as String?) ?? '—',
      author: (raw['author'] as String?) ?? 'Noma\'lum',
      description: (raw['description'] as String?) ?? '',
      coverUrl: (raw['thumbnail'] as String?) ?? '',
      audioUrl: (raw['audioUrl'] as String?) ?? '',
      durationSeconds: durationSec,
      duration: _formatDuration(durationSec),
      category: category?.isNotEmpty == true ? _humanCategory(category!) : 'Boshqa',
      hashtags: ['#$ageFrom-${ageTo}yosh'],
      listenCount: (raw['listens'] as num?)?.toInt() ?? 0,
      coverColor: _coverColorFor(id),
    );
  }

  String _humanCategory(String slug) {
    switch (slug) {
      case 'badiiy':
        return 'Badiiy';
      case 'sarguzasht':
        return 'Sarguzasht';
      case 'ertaklar':
        return 'Ertaklar';
      case 'fan':
        return 'Fan';
      default:
        return slug;
    }
  }

  String _formatDuration(int sec) {
    if (sec <= 0) return '0:00';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}s ${m}d';
    return '$m daq';
  }

  Color _coverColorFor(String id) {
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
