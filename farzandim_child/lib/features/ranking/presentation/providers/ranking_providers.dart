// ─────────────────────────────────────────────────────────────────────
// ranking_providers — tab/range/filter state + computed users
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.7c: real backend `/api/content/olympiads/ranking` ulanishi.
// `backendRankingProvider` tanlangan TimeRange asosida fetch qiladi,
// muvaffaqiyatli bo'lsa shu ro'yxat ishlatiladi, aks holda MockRanking
// fallback.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/data/repositories/ranking_backend_repository.dart';

enum RankingTab { umumiy, hudud, yoshGuruhi }

enum TimeRange { kunlik, haftalik, oylik, butunDavr }

final rankingTabProvider =
    StateProvider<RankingTab>((ref) => RankingTab.umumiy);

final timeRangeProvider =
    StateProvider<TimeRange>((ref) => TimeRange.haftalik);

final selectedRegionProvider = StateProvider<String?>((ref) => null);
final selectedYoshGuruhiProvider =
    StateProvider<String?>((ref) => null);

final backendRankingProvider = FutureProvider<RankingResult>((ref) async {
  final range = ref.watch(timeRangeProvider);
  final apiRange = switch (range) {
    TimeRange.kunlik => 'daily',
    TimeRange.haftalik => 'weekly',
    TimeRange.oylik => 'monthly',
    TimeRange.butunDavr => 'all',
  };
  return ref.watch(rankingBackendRepositoryProvider).fetchRanking(range: apiRange);
});

final allUsersProvider = Provider<List<RankingUser>>((ref) {
  final async = ref.watch(backendRankingProvider);
  return async.maybeWhen(
    data: (result) => result.users,
    orElse: () => const <RankingUser>[],
  );
});

final filteredUsersProvider = Provider<List<RankingUser>>((ref) {
  final users = ref.watch(allUsersProvider);
  final tab = ref.watch(rankingTabProvider);
  final timeRange = ref.watch(timeRangeProvider);
  final region = ref.watch(selectedRegionProvider);
  final yoshGuruhi = ref.watch(selectedYoshGuruhiProvider);

  final currentUser = users
      .cast<RankingUser?>()
      .firstWhere((u) => u?.isCurrentUser ?? false, orElse: () => null);

  var filtered = users;

  if (tab == RankingTab.hudud) {
    final r = region ?? currentUser?.region;
    filtered = filtered.where((u) => u.region == r).toList();
  } else if (tab == RankingTab.yoshGuruhi) {
    final y = yoshGuruhi ?? currentUser?.yoshGuruhi;
    filtered = filtered.where((u) => u.yoshGuruhi == y).toList();
  }

  filtered = [...filtered]
    ..sort((a, b) =>
        scoreFor(b, timeRange).compareTo(scoreFor(a, timeRange)));

  return filtered;
});

final currentUserRankProvider = Provider<int>((ref) {
  final filtered = ref.watch(filteredUsersProvider);
  final index = filtered.indexWhere((u) => u.isCurrentUser);
  return index >= 0 ? index + 1 : -1;
});

int scoreFor(RankingUser user, TimeRange range) {
  switch (range) {
    case TimeRange.kunlik:
      return user.dailyScore;
    case TimeRange.haftalik:
      return user.weeklyScore;
    case TimeRange.oylik:
      return user.monthlyScore;
    case TimeRange.butunDavr:
      return user.totalScore;
  }
}
