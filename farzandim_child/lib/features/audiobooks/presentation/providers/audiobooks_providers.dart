// ─────────────────────────────────────────────────────────────────────
// audiobooks_providers — search, filter, computed sections
// ─────────────────────────────────────────────────────────────────────
//
// Audiokitoblar real backend `/api/content/audiobooks` dan keladi.
// Backend bola yoshi bo'yicha filtrlaydi — mock yo'q, bo'sh kelsa
// "kontent yo'q" ko'rsatamiz.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/repositories/audiobooks_backend_repository.dart';

final audiobookSearchQueryProvider = StateProvider<String>((ref) => '');

final audiobookCategoryFilterProvider =
    StateProvider<String?>((ref) => null);

final backendAudiobooksProvider = FutureProvider<List<AudiobookModel>>((ref) async {
  final repo = ref.watch(audiobooksBackendRepositoryProvider);
  return repo.fetchAudiobooks();
});

/// Backend qaytargan real ro'yxat. Mock fallback OLIB TASHLANDI: mock
/// kontent yosh filtridan o'tmaydi — bo'sh bo'lsa bo'sh ko'rsatamiz.
final effectiveAudiobooksProvider = Provider<List<AudiobookModel>>((ref) {
  return ref.watch(backendAudiobooksProvider).valueOrNull ?? const [];
});

final filteredAudiobooksProvider =
    Provider<List<AudiobookModel>>((ref) {
  final query = ref.watch(audiobookSearchQueryProvider).toLowerCase();
  final category = ref.watch(audiobookCategoryFilterProvider);

  var books = ref.watch(effectiveAudiobooksProvider);

  if (query.isNotEmpty) {
    books = books.where((b) {
      return b.title.toLowerCase().contains(query) ||
          b.author.toLowerCase().contains(query) ||
          b.category.toLowerCase().contains(query) ||
          b.hashtags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  if (category != null) {
    books = books.where((b) => b.category == category).toList();
  }

  return books;
});

final forYouAudiobooksProvider = Provider<List<AudiobookModel>>((ref) {
  return ref.watch(filteredAudiobooksProvider).take(5).toList();
});

final mostListenedProvider = Provider<List<AudiobookModel>>((ref) {
  final books = ref.watch(filteredAudiobooksProvider);
  final sorted = [...books]
    ..sort((a, b) => b.listenCount.compareTo(a.listenCount));
  return sorted.take(5).toList();
});

final newestAudiobooksProvider = Provider<List<AudiobookModel>>((ref) {
  return ref.watch(filteredAudiobooksProvider).reversed.take(5).toList();
});
