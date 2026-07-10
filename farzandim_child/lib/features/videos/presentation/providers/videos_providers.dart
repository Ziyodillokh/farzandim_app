// ─────────────────────────────────────────────────────────────────────
// videos_providers — Riverpod state va computed providerlar
// ─────────────────────────────────────────────────────────────────────
//
// `videoSearchQueryProvider`, `videoFilterProvider` — dashboard'ning
// "Trend videolar" bo'limi uchun (topVideosProvider zanjiri). Feed ekrani
// esa `videoCategoryProvider` + `videoFeedProvider` bilan janr bo'yicha
// filtrlaydi (kategoriya chip'lari).
//
// Videolar real backend `/api/content/videos` dan keladi. Backend bola
// yoshi (child.age) bo'yicha filtrlaydi — bu yerda mock yo'q, bo'sh kelsa
// "kontent yo'q" ko'rsatamiz.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/videos/data/models/filter_state.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';

final videoSearchQueryProvider = StateProvider<String>((ref) => '');

final videoFilterProvider = StateProvider<VideoFilterState>(
  (ref) => const VideoFilterState(),
);

/// Real backend'dan video ro'yxat. Bola hali pair qilinmagan bo'lsa
/// yoki 401/timeout bo'lsa exception qaytaradi → UI mock fallback ishlatadi.
///
/// Cache TTL: 30 soniya. Bundan keyin yangi screen mount'da fresh fetch —
/// admin yangi video (YouTube havola) qo'shgach bola tezda ko'radi (avval
/// 5 daqiqa edi, yangi kontent kech chiqardi). Pull-to-refresh ham bor.
/// `ref.invalidate(backendVideosProvider)` orqali manual refresh ham mumkin.
/// Cache-first (stale-while-revalidate): cold start'da lokal cache'dagi
/// videolar DARHOL qaytadi, parallelda fon'da backend'dan yangisi kelib
/// `state`'ni yangilaydi. Cache yo'q bo'lsa odatdagidek network kutiladi.
/// Offline bo'lsa cache qoladi (xato yutiladi). Watching → AsyncValue,
/// `.future`/`.valueOrNull` FutureProvider bilan bir xil — eski consumerlar
/// (pull-to-refresh `ref.read(...future)`) o'zgartirishsiz ishlaydi.
final backendVideosProvider =
    AsyncNotifierProvider<VideosNotifier, List<VideoModel>>(VideosNotifier.new);

class VideosNotifier extends AsyncNotifier<List<VideoModel>> {
  bool _disposed = false;

  @override
  Future<List<VideoModel>> build() async {
    ref.onDispose(() => _disposed = true);
    // 30s keepAlive: tez nav qaytishda qayta fetch qilmaydi (avvalgi xulq).
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 30), link.close);
    ref.onDispose(timer.cancel);

    final repo = ref.watch(videosBackendRepositoryProvider);
    final cached = await repo.cachedVideos();
    if (cached.isNotEmpty) {
      // Cache bor — darhol qaytaramiz, yangisini fon'da olamiz (build tugagach).
      Future.microtask(() => _refresh(repo));
      return cached;
    }
    // Cache yo'q (birinchi marta) — network kutiladi.
    return repo.fetchVideos();
  }

  Future<void> _refresh(VideosBackendRepository repo) async {
    try {
      final fresh = await repo.fetchVideos();
      if (_disposed) return;
      state = AsyncData(fresh);
    } catch (_) {
      // Offline/timeout: cache'dagi (allaqachon ko'rsatilgan) ro'yxat qoladi.
    }
  }
}

/// Backend qaytargan real ro'yxat. Mock fallback OLIB TASHLANDI: mock
/// kontent yosh filtridan o'tmaydi (backend child.age bo'yicha filtrlaydi),
/// shuning uchun bo'sh bo'lsa "Hech narsa yo'q" ko'rsatamiz — yoshga mos
/// bo'lmagan soxta video emas. Loading/xato paytida ham bo'sh.
final effectiveVideosProvider = Provider<List<VideoModel>>((ref) {
  return ref.watch(backendVideosProvider).valueOrNull ?? const [];
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
    videos = videos.where((v) => filter.sohalar.contains(v.soha)).toList();
  }
  if (filter.yonalishlar.isNotEmpty) {
    videos = videos
        .where((v) => filter.yonalishlar.contains(v.yonalish))
        .toList();
  }
  if (filter.fanlar.isNotEmpty) {
    videos = videos.where((v) => filter.fanlar.contains(v.category)).toList();
  }
  if (filter.yoshGuruhi != null) {
    videos = videos.where((v) => v.yoshGuruhi == filter.yoshGuruhi).toList();
  }

  return videos;
});

final topVideosProvider = Provider<List<VideoModel>>((ref) {
  final videos = ref.watch(filteredVideosProvider);
  final sorted = [...videos]..sort((a, b) => b.views.compareTo(a.views));
  return sorted.take(5).toList();
});

// ── Feed ekrani (kategoriya chip'lari) ──────────────────────────────────

/// Feed kategoriya chip'lari — yuklangan videolardagi mavjud janrlar
/// (`category`, backend slug'i humanlashtirilgan), birinchi uchrash tartibida.
/// UI oldiga "Barchasi" chip qo'shadi. "Boshqa" (kategoriyasiz) chip
/// ko'rsatilmaydi. Janr topilmasa ro'yxat bo'sh (chip qatori chiqmaydi).
final videoCategoriesProvider = Provider<List<String>>((ref) {
  final videos = ref.watch(effectiveVideosProvider);
  final seen = <String>{};
  final result = <String>[];
  for (final v in videos) {
    final g = v.category.trim();
    if (g.isNotEmpty && g != 'Boshqa' && seen.add(g)) result.add(g);
  }
  return result;
});

/// Tanlangan feed kategoriyasi (`null` = Barchasi). Chip bosilganda yoziladi.
final videoCategoryProvider = StateProvider<String?>((ref) => null);

/// Tanlangan kategoriya, mavjud chip'lar bilan solishtirilgan. Videolar qayta
/// yuklanib tanlangan janr yo'qolsa `null`ga (Barchasi) tushadi — aks holda
/// feed bo'sh qolib, hech chip yonmagan nomuvofiq holat yuzaga kelardi.
final effectiveVideoCategoryProvider = Provider<String?>((ref) {
  final selected = ref.watch(videoCategoryProvider);
  if (selected == null) return null;
  return ref.watch(videoCategoriesProvider).contains(selected)
      ? selected
      : null;
});

/// Feed'da ko'rsatiladigan videolar — tanlangan (mavjud) kategoriya bo'yicha
/// filtrlangan (null bo'lsa hammasi). Search/murakkab filtr bu ekranda yo'q.
final videoFeedProvider = Provider<List<VideoModel>>((ref) {
  final selected = ref.watch(effectiveVideoCategoryProvider);
  final videos = ref.watch(effectiveVideosProvider);
  if (selected == null) return videos;
  return videos.where((v) => v.category.trim() == selected).toList();
});
