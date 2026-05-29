// ─────────────────────────────────────────────────────────────────────
// videos_providers — Riverpod state va computed providerlar
// ─────────────────────────────────────────────────────────────────────
//
// `videoSearchQueryProvider`, `videoFilterProvider` — foydalanuvchi
// inputi. `filteredVideosProvider` ulardan computed; `topVideos`,
// `recommendedVideos`, `heroVideo` esa filtered'dan derive bo'ladi.
//
// Sprint 5.7b: real backend `/api/content/videos` ulanishi qo'shildi.
// `backendVideosProvider` FutureProvider sifatida fetch qiladi; agar
// muvaffaqiyatli bo'lsa shu ro'yxat ishlatiladi, bo'lmasa MockVideos
// fallback. Shu bilan offline / hali pair qilinmagan holatlarda ham
// UI sinmaydi.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/videos/data/models/filter_state.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';

final videoSearchQueryProvider = StateProvider<String>((ref) => '');

final videoFilterProvider =
    StateProvider<VideoFilterState>((ref) => const VideoFilterState());

/// 0 — Following, 1 — Siz uchun. Default: Siz uchun.
final videoActiveTabProvider = StateProvider<int>((ref) => 1);

/// Real backend'dan video ro'yxat. Bola hali pair qilinmagan bo'lsa
/// yoki 401/timeout bo'lsa exception qaytaradi → UI mock fallback ishlatadi.
///
/// Cache TTL: 5 daqiqa. Bundan keyin yangi screen mount'da fresh fetch.
/// `ref.invalidate(backendVideosProvider)` orqali manual refresh ham mumkin.
final backendVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  // 5 daqiqalik auto-dispose: agar 5 minut hech kim watch qilmasa, provider
  // qayta ishga tushganda fresh fetch qiladi (eski admin upload videolar
  // tomonidan o'chirilgan list'ni stale ko'rsatmaslik uchun).
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(videosBackendRepositoryProvider);
  return repo.fetchVideos();
});

/// `ref.cacheFor` polyfill — Riverpod 3.x'da native, hozircha extension.
extension _RefCache on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

/// Real backend ma'lumotini ishlatadi, agar mavjud va bo'sh emas bo'lsa;
/// aks holda mock. Offline va dev rejimida UI sinmaydi.
final effectiveVideosProvider = Provider<List<VideoModel>>((ref) {
  final async = ref.watch(backendVideosProvider);
  return async.maybeWhen(
    data: (list) => list,
    orElse: () => const <VideoModel>[],
  );
});

final filteredVideosProvider = Provider<List<VideoModel>>((ref) {
  final query = ref.watch(videoSearchQueryProvider).toLowerCase();
  final filter = ref.watch(videoFilterProvider);

  var videos = ref.watch(effectiveVideosProvider);

  if (query.isNotEmpty) {
    videos = videos.where((v) {
      return v.title.toLowerCase().contains(query) ||
          v.description.toLowerCase().contains(query) ||
          v.category.toLowerCase().contains(query) ||
          v.hashtags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  if (filter.sohalar.isNotEmpty) {
    videos =
        videos.where((v) => filter.sohalar.contains(v.soha)).toList();
  }
  if (filter.yonalishlar.isNotEmpty) {
    videos = videos
        .where((v) => filter.yonalishlar.contains(v.yonalish))
        .toList();
  }
  if (filter.fanlar.isNotEmpty) {
    videos =
        videos.where((v) => filter.fanlar.contains(v.category)).toList();
  }
  if (filter.yoshGuruhi != null) {
    videos =
        videos.where((v) => v.yoshGuruhi == filter.yoshGuruhi).toList();
  }

  return videos;
});

final topVideosProvider = Provider<List<VideoModel>>((ref) {
  final videos = ref.watch(filteredVideosProvider);
  final sorted = [...videos]..sort((a, b) => b.views.compareTo(a.views));
  return sorted.take(5).toList();
});

final recommendedVideosProvider = Provider<List<VideoModel>>((ref) {
  final videos = ref.watch(filteredVideosProvider);
  return videos.reversed.take(5).toList();
});

final heroVideoProvider = Provider<VideoModel?>((ref) {
  final videos = ref.watch(filteredVideosProvider);
  return videos.isNotEmpty ? videos.first : null;
});
