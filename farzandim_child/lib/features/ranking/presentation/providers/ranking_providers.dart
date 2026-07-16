// ─────────────────────────────────────────────────────────────────────
// ranking_providers — tab/range/filter state + computed users
// ─────────────────────────────────────────────────────────────────────
//
// Yagona DON reytingi — `/api/leaderboard`. `backendRankingProvider` tanlangan
// TimeRange asosida fetch qiladi; xato bo'lsa ro'yxat bo'sh ko'rinadi (mock
// fallback yo'q).
//
// Avval bu ekran `/api/content/olympiads/ranking` dan olimpiada ballarini olib
// "DON" deb ko'rsatardi — ota-ona ilovasidagi DON bilan mos kelmasdi.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
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

  // Viloyat filtri SERVER tomonda. "Hudud" tab'ida top-N o'sha viloyat
  // ichidan olinadi; viloyat tanlanmagan bo'lsa `'me'` — bolaning o'z
  // viloyati (klient o'z viloyatini mustaqil bilmaydi). Boshqa tab'larda
  // region yuborilmaydi → global reyting.
  //
  // Avval region umuman yuborilmasdi va klient global top-50 ni o'zi
  // filtrlardi → boshqa viloyat bolasi ro'yxatga tushmasa natija bo'sh
  // bo'lib, "filtr ishlamayapti" holati kelib chiqardi.
  final tab = ref.watch(rankingTabProvider);
  final selectedRegion = ref.watch(selectedRegionProvider);
  final region = tab == RankingTab.hudud ? (selectedRegion ?? 'me') : null;

  // "Siz" qatorini backend emas, childId taqqoslash orqali aniqlaymiz —
  // `/leaderboard` har qatorda `isCurrentUser` bermaydi.
  final childId = ref.watch(pairingStateProvider).childId;

  return ref
      .watch(rankingBackendRepositoryProvider)
      .fetchRanking(childId: childId, range: apiRange, region: region);
});

/// Real backend ma'lumotidan foydalanadi. Backend bo'sh bo'lsa —
/// ro'yxat bo'sh ko'rinadi (real holat). Mock fallback yo'q.
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
  final yoshGuruhi = ref.watch(selectedYoshGuruhiProvider);

  final currentUser = users
      .cast<RankingUser?>()
      .firstWhere((u) => u?.isCurrentUser ?? false, orElse: () => null);

  var filtered = users;

  // HUDUD: filtr SERVER tomonda qo'llangan (`backendRankingProvider` region
  // yuboradi) — bu yerda QAYTA filtrlamaymiz. Avval global top-50 ustida
  // klient filtri ishlab, ro'yxat bo'sh chiqardi.
  if (tab == RankingTab.yoshGuruhi) {
    // YOSH: backend yosh filtrini qo'llamaydi (javobda `age` bor) →
    // klientda filtrlaymiz.
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
