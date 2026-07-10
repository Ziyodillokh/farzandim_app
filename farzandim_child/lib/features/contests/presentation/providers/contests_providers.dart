// ─────────────────────────────────────────────────────────────────────
// contests_providers — testlar ro'yxati + featured + sevimlilar
// ─────────────────────────────────────────────────────────────────────
//
// Real backend `/api/content/olympiads` (yosh filtri backend'da). Grid
// `allTestsProvider` (faol + yakunlangan), hero `featuredContestProvider`.
// Sevimlilar — lokal (SharedPreferences), header ♡ tugmasi uchun.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/repositories/contests_backend_repository.dart';

final backendContestsProvider = FutureProvider<ContestBundle>((ref) async {
  final repo = ref.watch(contestsBackendRepositoryProvider);
  return repo.fetchContests();
});

final activeContestsProvider = Provider<List<ContestModel>>((ref) {
  return ref
      .watch(backendContestsProvider)
      .maybeWhen(
        data: (bundle) => bundle.active,
        orElse: () => const <ContestModel>[],
      );
});

final finishedContestsProvider = Provider<List<ContestModel>>((ref) {
  return ref
      .watch(backendContestsProvider)
      .maybeWhen(
        data: (bundle) => bundle.finished,
        orElse: () => const <ContestModel>[],
      );
});

/// Grid uchun barcha testlar — faol (avval), keyin yakunlangan.
final allTestsProvider = Provider<List<ContestModel>>((ref) {
  return [
    ...ref.watch(activeContestsProvider),
    ...ref.watch(finishedContestsProvider),
  ];
});

/// Hero karta uchun tanlangan test — birinchi faol (bo'lmasa null).
final featuredContestProvider = Provider<ContestModel?>((ref) {
  final active = ref.watch(activeContestsProvider);
  return active.isNotEmpty ? active.first : null;
});

/// Yuklanmoqdami — UI spinner uchun.
final contestsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(backendContestsProvider).isLoading;
});

/// Tarmoq/server xatosi — xato+qayta urinish ko'rsatish uchun.
final contestsErrorProvider = Provider<bool>((ref) {
  return ref.watch(backendContestsProvider).hasError;
});

// ════════════ Sevimli testlar (lokal, SharedPreferences) ════════════

const String _favKey = 'favorite_contest_ids_v1';

/// Sevimli test ID'lari (header ♡ / long-press). Lokal — testlar cheklangan
/// to'plam, backend shart emas (bookmark).
final favoriteContestIdsProvider =
    NotifierProvider<FavoriteContestIdsNotifier, Set<String>>(
      FavoriteContestIdsNotifier.new,
    );

/// Sevimlilar to'plami — toggle + disk persist (restore tugagach mutatsiya).
class FavoriteContestIdsNotifier extends Notifier<Set<String>> {
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
      // Xato — bo'sh qoladi.
    }
  }

  /// Sevimliga qo'shish/olib tashlash. `true` — qo'shildi.
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

/// Sevimli testlar — hozir mavjudlari (allTests ichidan), allTests tartibida.
final favoriteContestsProvider = Provider<List<ContestModel>>((ref) {
  final ids = ref.watch(favoriteContestIdsProvider);
  return ref.watch(allTestsProvider).where((c) => ids.contains(c.id)).toList();
});
