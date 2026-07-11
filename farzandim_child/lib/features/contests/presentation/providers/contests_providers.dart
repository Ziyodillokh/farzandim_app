// ─────────────────────────────────────────────────────────────────────
// contests_providers — testlar ro'yxati + featured + sevimlilar
// ─────────────────────────────────────────────────────────────────────
//
// Real backend `/api/content/olympiads` (yosh filtri backend'da). Grid
// `allTestsProvider` (faol + yakunlangan), hero `featuredContestProvider`.
// Sevimlilar — lokal (SharedPreferences), header ♡ tugmasi uchun.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/test_difficulty.dart';
import 'package:farzandim_child/features/contests/data/repositories/contests_backend_repository.dart';

/// Boshlanayotgan test uchun tanlangan qiyinlik ("Konkurs shartlari" sheet).
/// Quiz `_start()` shu qiymatdan per-savol vaqtini oladi. Boshlashdan oldin
/// sheet yozadi.
final selectedTestDifficultyProvider = StateProvider<TestDifficulty>(
  (ref) => TestDifficulty.orta,
);

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

// ════════════ Sevimli testlar (lokal, TO'LIQ MODEL saqlanadi) ════════════

// MUHIM: sevimlilar to'liq ContestModel bilan saqlanadi (JSON), jonli
// backendContestsProvider snapshot'iga BOG'LIQ EMAS. Avval faqat ID saqlanib,
// ro'yxat allTests'dan filtrlanardi — dashboard har 60s + resume'da
// invalidate qilgani uchun reload paytida allTests bo'sh bo'lib, sevimlilar
// "yo'qolib" ko'rinardi ("sevimlilarga to'g'ri qo'shilmayapti").
const String _favContestsKey = 'favorite_contests_v1';

final favoriteContestsProvider =
    NotifierProvider<FavoriteContestsNotifier, List<ContestModel>>(
      FavoriteContestsNotifier.new,
    );

/// Sevimli testlar — model bilan persist, eng oxirgi qo'shilgan birinchi.
class FavoriteContestsNotifier extends Notifier<List<ContestModel>> {
  Future<void>? _ready;

  @override
  List<ContestModel> build() {
    _ready = _restore();
    return const [];
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favContestsKey);
      if (raw == null) return;
      state = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ContestModel.fromJson)
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) {
      // Buzuq JSON — bo'sh qoladi.
    }
  }

  bool contains(String id) => state.any((c) => c.id == id);

  /// Toggle — qo'shilsa `true`. Yangi sevimli ro'yxat BOSHIGA.
  Future<bool> toggle(ContestModel contest) async {
    await _ready;
    final exists = state.any((c) => c.id == contest.id);
    final next = exists
        ? state.where((c) => c.id != contest.id).toList()
        : <ContestModel>[contest, ...state];
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _favContestsKey,
        jsonEncode(next.map((c) => c.toJson()).toList()),
      );
    } catch (_) {
      // Saqlash xatosi — state sessiya davomida baribir o'zgardi.
    }
    return !exists;
  }
}
