// ─────────────────────────────────────────────────────────────────────
// video_engagement_providers — Sevimlilar + Ko'rish tarixi (backend + lokal)
// ─────────────────────────────────────────────────────────────────────
//
// Sahifalar (Ko'rish tarixi / Yoqtirilgan videolar) backend'dan to'liq video
// + vaqt bilan keladi (VideoEngagementRepository, offline kesh bilan).
//
// `favoriteVideoIdsProvider` — feed'dagi ♡ holati + long-press toggle uchun
// LOKAL to'plam (SharedPreferences, instant/offline). Ochilganda backend'dan
// sinxronlanadi (source of truth), toggle backend'ga yoziladi. Foydalanuvchi
// toggle qilsa, keyin kelgan backend sync uni bosib ketmaydi (_mutated).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/videos/data/repositories/video_engagement_repository.dart';

const String _favKey = 'favorite_video_ids_v1';

/// Yoqtirilgan video ID'lari (lokal, feed ♡). Backend bilan sinxronlanadi.
final favoriteVideoIdsProvider =
    NotifierProvider<FavoriteVideoIdsNotifier, Set<String>>(
      FavoriteVideoIdsNotifier.new,
    );

/// Sevimlilar to'plami — lokal cache + backend sync + optimistic toggle.
class FavoriteVideoIdsNotifier extends Notifier<Set<String>> {
  Future<void>? _ready; // lokal restore (toggle shuni kutadi — tez)
  bool _mutated =
      false; // foydalanuvchi toggle qilganmi (sync clobber'ini oldini oladi)

  @override
  Set<String> build() {
    _ready = _restoreLocal();
    _syncFromBackend();
    return const {};
  }

  Future<void> _restoreLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (prefs.getStringList(_favKey) ?? const <String>[]).toSet();
    } catch (_) {
      // Xato — bo'sh qoladi.
    }
  }

  // Bu qurilma yoqtirilganlar uchun ASOSIY manba. Backend faqat REINSTALL /
  // birinchi ochilishda tiklash uchun ishlatiladi: lokalda allaqachon
  // yoqtirilganlar bo'lsa (yoki foydalanuvchi tegib bo'lsa) backend'ni qayta
  // YOZMAYMIZ — aks holda offline qilingan (un)favorite keyingi ochilishda
  // bekor bo'lardi. Lokal bo'sh bo'lsagina backend'dan to'ldiramiz.
  Future<void> _syncFromBackend() async {
    await _ready;
    if (_mutated || state.isNotEmpty) return;
    final ids = await ref
        .read(videoEngagementRepositoryProvider)
        .fetchFavoriteIds();
    if (ids != null && !_mutated && state.isEmpty) {
      state = ids.toSet();
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favKey, state.toList());
    } catch (_) {
      // Saqlash xatosi — sessiya davomida state baribir o'zgardi.
    }
  }

  /// Toggle — yangi holat (qo'shildi=true) qaytaradi.
  Future<bool> toggle(String id) async {
    await _ready;
    final added = !state.contains(id);
    await setFavorite(id, favorite: added);
    return added;
  }

  /// Aniq holat o'rnatadi (feed long-press yoki liked-page unfavorite).
  Future<void> setFavorite(String id, {required bool favorite}) async {
    await _ready;
    _mutated = true;
    final next = {...state};
    final changed = favorite ? next.add(id) : next.remove(id);
    if (!changed) return; // allaqachon shu holatda
    state = next;
    await _persist();
    final repo = ref.read(videoEngagementRepositoryProvider);
    if (favorite) {
      await repo.addFavorite(id);
    } else {
      await repo.removeFavorite(id);
    }
  }
}

/// Ko'rish tarixi sahifasi — backend (offline kesh bilan), yangi → eski.
/// autoDispose: sahifa har ochilganda qayta fetch (yangi ko'rilganlar chiqadi).
final watchHistoryPageProvider =
    AsyncNotifierProvider.autoDispose<
      WatchHistoryPageNotifier,
      List<VideoEngagementEntry>
    >(WatchHistoryPageNotifier.new);

class WatchHistoryPageNotifier
    extends AutoDisposeAsyncNotifier<List<VideoEngagementEntry>> {
  @override
  Future<List<VideoEngagementEntry>> build() {
    return ref.read(videoEngagementRepositoryProvider).fetchHistory();
  }

  Future<void> refresh() async {
    // AsyncLoading o'rnatmaymiz — pull-to-refresh'da eski ro'yxat ko'rinib
    // tursin (RefreshIndicator o'z spinnerini ko'rsatadi).
    state = await AsyncValue.guard(
      () => ref.read(videoEngagementRepositoryProvider).fetchHistory(),
    );
  }
}

/// Yoqtirilgan videolar sahifasi — backend (offline kesh bilan), yangi → eski.
/// autoDispose: sahifa har ochilganda qayta fetch (yangi yoqtirilganlar chiqadi).
final likedVideosPageProvider =
    AsyncNotifierProvider.autoDispose<
      LikedVideosPageNotifier,
      List<VideoEngagementEntry>
    >(LikedVideosPageNotifier.new);

class LikedVideosPageNotifier
    extends AutoDisposeAsyncNotifier<List<VideoEngagementEntry>> {
  @override
  Future<List<VideoEngagementEntry>> build() {
    return ref.read(videoEngagementRepositoryProvider).fetchFavorites();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(videoEngagementRepositoryProvider).fetchFavorites(),
    );
  }

  /// Yoqtirilgandan olib tashlash — lokal ♡ set + backend + ro'yxatdan.
  Future<void> unfavorite(String id) async {
    await ref
        .read(favoriteVideoIdsProvider.notifier)
        .setFavorite(id, favorite: false);
    final current = state.valueOrNull ?? const <VideoEngagementEntry>[];
    state = AsyncData(
      current.where((e) => e.video.id != id).toList(growable: false),
    );
  }
}
