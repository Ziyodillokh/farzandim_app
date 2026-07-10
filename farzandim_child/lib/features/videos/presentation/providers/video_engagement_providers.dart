// ─────────────────────────────────────────────────────────────────────
// video_engagement_providers — Sevimlilar + Ko'rish tarixi
// ─────────────────────────────────────────────────────────────────────
//
// Videolar feed header'idagi ikki tugma uchun state:
//   ♡  Sevimlilar    — feed kartani BOSIB TURISH (long-press) bilan toggle
//   ⟲  Ko'rish tarixi — video ochilganda (/video-player) avtomatik yoziladi
//
// Ikkalasi ham SharedPreferences'da saqlanadi (offline, app qayta ochilganda
// tiklanadi) — themeModeProvider bilan bir xil Notifier + async _restore pattern.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';

const String _favKey = 'favorite_video_ids_v1';
const String _historyKey = 'watch_history_ids_v1';
const int _historyCap = 30;

/// Sevimli video ID'lari (SharedPreferences'da saqlanadi).
final favoriteVideoIdsProvider =
    NotifierProvider<FavoriteVideoIdsNotifier, Set<String>>(
      FavoriteVideoIdsNotifier.new,
    );

/// Sevimlilar to'plamini boshqaradi — toggle + disk persist.
class FavoriteVideoIdsNotifier extends Notifier<Set<String>> {
  // _restore Future — mutatsiya restore tugaguncha kutadi (saqlangan ma'lumot
  // yo'qolmasin: aks holda restore'dan oldingi toggle bo'sh state'ni yozib
  // qo'yardi).
  Future<void>? _ready;

  @override
  Set<String> build() {
    _ready = _restore();
    return const {};
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (prefs.getStringList(_favKey) ?? const <String>[]).toSet();
    } catch (_) {
      // Xato — bo'sh to'plam qoladi.
    }
  }

  /// Sevimliga qo'shish/olib tashlash. `true` — qo'shildi, `false` — olib tashlandi.
  Future<bool> toggle(String id) async {
    await _ready;
    final next = {...state};
    final added = next.add(id);
    if (!added) next.remove(id);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favKey, next.toList());
    } catch (_) {
      // Saqlash xatosi — state sessiya davomida baribir o'zgardi.
    }
    return added;
  }
}

/// Ko'rish tarixi — eng oxirgi ochilgan video ID'lari (yangi → eski).
final watchHistoryIdsProvider =
    NotifierProvider<WatchHistoryIdsNotifier, List<String>>(
      WatchHistoryIdsNotifier.new,
    );

/// Tarixni boshqaradi — video ochilganda `record`, disk persist, cap 30.
class WatchHistoryIdsNotifier extends Notifier<List<String>> {
  Future<void>? _ready;

  @override
  List<String> build() {
    _ready = _restore();
    return const [];
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getStringList(_historyKey) ?? const <String>[];
    } catch (_) {
      // Xato — bo'sh tarix qoladi.
    }
  }

  /// Video ochilganda chaqiriladi — ID ro'yxat boshiga (takror olib tashlanadi).
  Future<void> record(String id) async {
    await _ready;
    final next = <String>[id, ...state.where((e) => e != id)];
    if (next.length > _historyCap) next.removeRange(_historyCap, next.length);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, next);
    } catch (_) {
      // Saqlash xatosi — state sessiya davomida baribir o'zgardi.
    }
  }
}

/// Sevimli videolar — hozir feed'da mavjud bo'lganlari (ID → model).
final favoriteVideosProvider = Provider<List<VideoModel>>((ref) {
  final ids = ref.watch(favoriteVideoIdsProvider);
  return ref
      .watch(effectiveVideosProvider)
      .where((v) => ids.contains(v.id))
      .toList();
});

/// Ko'rish tarixidagi videolar — tarix tartibida (yangi → eski), mavjudlari.
final watchHistoryVideosProvider = Provider<List<VideoModel>>((ref) {
  final ids = ref.watch(watchHistoryIdsProvider);
  final byId = {for (final v in ref.watch(effectiveVideosProvider)) v.id: v};
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
});
