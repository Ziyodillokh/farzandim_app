// ─────────────────────────────────────────────────────────────────────
// RecommendationsRepository — onboarding interests asosida tavsiyalar
// ─────────────────────────────────────────────────────────────────────
//
// Backend endpoint:
//   GET /api/content/recommended
//     → { interests: [..], videos: [...], audiobooks: [...], books: [...] }
//
// Bola onboarding 4-slaydida tanlagan qiziqishlar (ID'lar) backend'dagi
// Child.interests bilan saralangan kontent ro'yxatini qaytaradi. Har bir
// tur uchun 5 ta element. Hech narsa tanlanmagan bo'lsa "ommabop" bilan
// to'ldiriladi (UI hech qachon bo'sh emas).

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';

class RecommendedContent {
  const RecommendedContent({
    required this.interests,
    required this.videos,
    required this.audiobooks,
  });

  /// Backend qaytargan tanlangan interest ID'lari (debug/UI uchun).
  final List<String> interests;
  final List<VideoModel> videos;
  final List<AudiobookModel> audiobooks;

  bool get isEmpty => videos.isEmpty && audiobooks.isEmpty;
}

final recommendationsRepositoryProvider =
    Provider<RecommendationsRepository>((ref) {
  return RecommendationsRepository(dio: ref.watch(dioClientProvider));
});

class RecommendationsRepository {
  RecommendationsRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<RecommendedContent> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/content/recommended');
      final data = response.data ?? const {};
      final interests = ((data['interests'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(growable: false);
      final videos = ((data['videos'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_toVideoModel)
          .toList(growable: false);
      final audiobooks = ((data['audiobooks'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_toAudiobookModel)
          .toList(growable: false);
      return RecommendedContent(
        interests: interests,
        videos: videos,
        audiobooks: audiobooks,
      );
    } on DioException catch (e) {
      debugPrint('Recommendations.fetch: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  VideoModel _toVideoModel(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    final durationSec = (raw['durationSec'] as num?)?.toInt() ?? 0;
    final ageFrom = (raw['ageFrom'] as num?)?.toInt() ?? 0;
    final ageTo = (raw['ageTo'] as num?)?.toInt() ?? 18;
    final category = (raw['category'] as String?)?.trim() ?? '';
    return VideoModel(
      id: id,
      title: (raw['title'] as String?) ?? '—',
      description: (raw['description'] as String?) ?? '',
      thumbnailUrl: (raw['thumbnail'] as String?) ?? '',
      duration: _formatDuration(durationSec),
      durationSeconds: durationSec,
      videoUrl: (raw['url'] as String?) ?? '',
      category: category.isNotEmpty ? category : 'Boshqa',
      soha: 'Aralash',
      yonalish: "Ta'lim",
      yoshGuruhi: '$ageFrom-$ageTo',
      hashtags: const [],
      views: (raw['views'] as num?)?.toInt() ?? 0,
      thumbnailColor: _paletteColorFor(id),
    );
  }

  AudiobookModel _toAudiobookModel(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    final durationSec = (raw['durationSec'] as num?)?.toInt() ?? 0;
    final ageFrom = (raw['ageFrom'] as num?)?.toInt() ?? 0;
    final ageTo = (raw['ageTo'] as num?)?.toInt() ?? 18;
    final category = (raw['category'] as String?)?.trim() ?? '';
    return AudiobookModel(
      id: id,
      title: (raw['title'] as String?) ?? '—',
      author: (raw['author'] as String?) ?? 'common.unknown'.tr(),
      description: (raw['description'] as String?) ?? '',
      coverUrl: (raw['thumbnail'] as String?) ?? '',
      audioUrl: (raw['audioUrl'] as String?) ?? '',
      durationSeconds: durationSec,
      duration: _formatDuration(durationSec),
      category: category.isNotEmpty ? category : 'Boshqa',
      hashtags: ['#$ageFrom-${ageTo}yosh'],
      listenCount: (raw['listens'] as num?)?.toInt() ?? 0,
      coverColor: _paletteColorFor(id),
    );
  }

  Color _paletteColorFor(String id) {
    if (id.isEmpty) return AppColors.catIndigo;
    int hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    const palette = <Color>[
      AppColors.catIndigo,
      AppColors.catPink,
      AppColors.catEmerald,
      AppColors.catTeal,
      AppColors.catPurple,
      AppColors.catOrangeDark,
      AppColors.catLavenderDark,
    ];
    return palette[hash % palette.length];
  }

  String _formatDuration(int sec) {
    if (sec <= 0) return '0:00';
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 10 daqiqalik cache — tez-tez chaqirilmasligi uchun.
/// Manual refresh: `ref.invalidate(recommendedContentProvider)`.
final recommendedContentProvider =
    FutureProvider<RecommendedContent>((ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);

  final repo = ref.watch(recommendationsRepositoryProvider);
  return repo.fetch();
});
