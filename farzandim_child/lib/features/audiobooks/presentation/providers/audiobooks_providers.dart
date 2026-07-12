// ─────────────────────────────────────────────────────────────────────
// audiobooks_providers — search, filter, computed sections
// ─────────────────────────────────────────────────────────────────────
//
// Audiokitoblar real backend `/api/content/audiobooks` dan keladi.
// Backend bola yoshi bo'yicha filtrlaydi. Backend bo'sh yoki kam
// (< 4) kitob qaytarsa, dizayn ko'rsatish uchun mahalliy MOCK katalog
// bilan to'ldiriladi (release build'da .env bilan o'chiriladi).

import 'dart:async';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/repositories/audiobooks_backend_repository.dart';

final audiobookSearchQueryProvider = StateProvider<String>((ref) => '');

final audiobookCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Cache-first (stale-while-revalidate) — cold start'da cache'dagi audiokitoblar
/// DARHOL, fon'da backend yangilaydi. Offline'da cache qoladi.
final backendAudiobooksProvider =
    AsyncNotifierProvider<AudiobooksNotifier, List<AudiobookModel>>(
      AudiobooksNotifier.new,
    );

class AudiobooksNotifier extends AsyncNotifier<List<AudiobookModel>> {
  bool _disposed = false;

  @override
  Future<List<AudiobookModel>> build() async {
    ref.onDispose(() => _disposed = true);
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 30), link.close);
    ref.onDispose(timer.cancel);

    final repo = ref.watch(audiobooksBackendRepositoryProvider);
    final cached = await repo.cachedAudiobooks();
    if (cached.isNotEmpty) {
      Future.microtask(() => _refresh(repo));
      return cached;
    }
    return repo.fetchAudiobooks();
  }

  Future<void> _refresh(AudiobooksBackendRepository repo) async {
    try {
      final fresh = await repo.fetchAudiobooks();
      if (_disposed) return;
      state = AsyncData(fresh);
    } catch (_) {
      /* offline: cache qoladi */
    }
  }
}

/// Backend qaytargan real ro'yxat, ba'zi holatlarda MOCK katalog
/// bilan boyitilgan (dizayn ko'rsatish uchun). Backend ko'p kitob
/// qaytarsa mock qo'shilmaydi.
final effectiveAudiobooksProvider = Provider<List<AudiobookModel>>((ref) {
  final real = ref.watch(backendAudiobooksProvider).valueOrNull ?? const [];
  if (real.length >= 4) return real;
  // Kam kelsa: real + mock (takrorsiz id bilan)
  final existingIds = real.map((b) => b.id).toSet();
  final extras = _mockAudiobooks
      .where((m) => !existingIds.contains(m.id))
      .toList(growable: false);
  return [...real, ...extras];
});

// ─────────────────────────────────────────────────────────────────────
// Mock katalog — dizayn/dev uchun (screenshot bilan mos). Backend real
// kontent yubormaguncha ekranlar bo'sh qolmasin.
// ─────────────────────────────────────────────────────────────────────
const _mockAudiobooks = <AudiobookModel>[
  AudiobookModel(
    id: 'mock-james-giant-peach',
    title: 'James and the Giant Peach',
    author: 'Roald Dahl',
    description:
        "James sehrli bahaybat shaftoli ichida noodatiy safarga chiqadi.",
    coverUrl: 'https://covers.openlibrary.org/b/id/8231855-L.jpg',
    audioUrl: '',
    durationSeconds: 9600,
    duration: '2:40:00',
    category: 'Hikoya',
    hashtags: ['#7-12yosh', '#hikoya'],
    listenCount: 1240,
    coverColor: Color(0xFFF97316),
    partsCount: 6,
  ),
  AudiobookModel(
    id: 'mock-kite-for-moon',
    title: 'A Kite for Moon',
    author: 'Jane Yolen',
    description: "Kichkina bola oyga uchqun uchirib do'st bo'ladi.",
    coverUrl: 'https://covers.openlibrary.org/b/id/9871823-L.jpg',
    audioUrl: '',
    durationSeconds: 9600,
    duration: '2:40:00',
    category: 'Hikoya',
    hashtags: ['#5-10yosh', '#hikoya'],
    listenCount: 890,
    coverColor: AppColors.catIndigo,
    partsCount: 6,
  ),
  AudiobookModel(
    id: 'mock-yellowface',
    title: 'Yellowface',
    author: 'R. F. Kuang',
    description: 'Adabiyot dunyosining ichki tomonlari haqida hikoya.',
    coverUrl: 'https://covers.openlibrary.org/b/id/13205207-L.jpg',
    audioUrl: '',
    durationSeconds: 9600,
    duration: '2:40:00',
    category: 'Sarguzasht',
    hashtags: ['#12-18yosh', '#sarguzasht'],
    listenCount: 1560,
    coverColor: AppColors.accent,
    partsCount: 8,
  ),
  AudiobookModel(
    id: 'mock-night-ocean',
    title: 'The Night Ocean',
    author: 'Paul La Farge',
    description: 'Sirli okean va uning tunlarda uyg\'ongan hikoyalari.',
    coverUrl: 'https://covers.openlibrary.org/b/id/8231856-L.jpg',
    audioUrl: '',
    durationSeconds: 9600,
    duration: '2:40:00',
    category: 'Sarguzasht',
    hashtags: ['#10-18yosh', '#sarguzasht'],
    listenCount: 620,
    coverColor: Color(0xFF6B4423),
    partsCount: 10,
  ),
  AudiobookModel(
    id: 'mock-ertak-1',
    title: 'Yulduzli osmon',
    author: 'A. Obidjon',
    description: 'Bolalar uchun sehrli ertaklar to\'plami.',
    coverUrl: '',
    audioUrl: '',
    durationSeconds: 1620,
    duration: '27:00',
    category: 'Ertak',
    hashtags: ['#3-8yosh', '#ertak'],
    listenCount: 2340,
    coverColor: AppColors.catBlue,
    partsCount: 5,
  ),
  AudiobookModel(
    id: 'mock-ilm-1',
    title: 'Kichkintoy olim',
    author: 'M. Xoshimov',
    description: 'Ilm dunyosidagi qiziqarli kashfiyotlar.',
    coverUrl: '',
    audioUrl: '',
    durationSeconds: 2400,
    duration: '40:00',
    category: 'Ilm',
    hashtags: ['#8-14yosh', '#ilm'],
    listenCount: 780,
    coverColor: AppColors.catEmerald,
    partsCount: 4,
  ),
];

final filteredAudiobooksProvider = Provider<List<AudiobookModel>>((ref) {
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

/// Feed ekrani QIDIRUV matni — `audiobookSearchQueryProvider`dan ALOHIDA
/// (u dashboard newest/for-you/most-listened tomonidan ishlatiladi, feed
/// qidiruvi u yerlarga sizmasin).
final audiobookFeedSearchProvider = StateProvider<String>((ref) => '');

/// Feed grid'ida ko'rsatiladigan kitoblar. Qidiruv faol bo'lsa BARCHA
/// kitoblardan (sarlavha/muallif/kategoriya) qidiradi (kategoriyani e'tiborsiz);
/// aks holda tanlangan kategoriya bo'yicha (null = hammasi).
final audiobookFeedProvider = Provider<List<AudiobookModel>>((ref) {
  final query = ref.watch(audiobookFeedSearchProvider).trim().toLowerCase();
  final books = ref.watch(effectiveAudiobooksProvider);
  if (query.isNotEmpty) {
    return books.where((b) {
      return b.title.toLowerCase().contains(query) ||
          b.author.toLowerCase().contains(query) ||
          b.category.toLowerCase().contains(query);
    }).toList();
  }
  final category = ref.watch(audiobookCategoryFilterProvider);
  if (category == null) return books;
  return books.where((b) => b.category == category).toList();
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
