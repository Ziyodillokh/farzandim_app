// ─────────────────────────────────────────────────────────────────────
// leaderboard_provider — paginated reyting holati (period + viloyat)
// ─────────────────────────────────────────────────────────────────────
//
// Family kaliti = (childId, period, region). Period yoki viloyat o'zgarsa
// yangi instance (toza ro'yxat). Bir instance ichida `loadMore()` keyingi
// sahifani qo'shadi (~15 tadan).

// ignore_for_file: public_member_api_docs

import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:farzandim/features/gamification/data/repositories/leaderboard_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef LeaderboardArgs = ({String childId, String period, String? region});

@immutable
class LeaderboardState {
  const LeaderboardState({
    this.entries = const [],
    this.currentChild,
    this.hasMore = true,
    this.initialLoading = true,
    this.loadingMore = false,
    this.error = false,
    this.page = 0,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentChild;
  final bool hasMore;
  final bool initialLoading;
  final bool loadingMore;
  final bool error;
  final int page;

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? currentChild,
    bool? hasMore,
    bool? initialLoading,
    bool? loadingMore,
    bool? error,
    int? page,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      currentChild: currentChild ?? this.currentChild,
      hasMore: hasMore ?? this.hasMore,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
      page: page ?? this.page,
    );
  }
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier(this._repo, this._args)
      : super(const LeaderboardState()) {
    _loadFirst();
  }

  final LeaderboardRepository _repo;
  final LeaderboardArgs _args;
  static const int _limit = 15;

  Future<void> _loadFirst() async {
    state = const LeaderboardState();
    try {
      final pageData = await _repo.fetch(
        childId: _args.childId,
        period: _args.period,
        region: _args.region,
        page: 1,
        limit: _limit,
      );
      state = state.copyWith(
        entries: pageData.entries,
        currentChild: pageData.currentChild,
        hasMore: pageData.hasMore,
        initialLoading: false,
        page: 1,
      );
    } catch (_) {
      state = state.copyWith(initialLoading: false, error: true, hasMore: false);
    }
  }

  /// Keyingi sahifa — ro'yxat oxiriga yetganda chaqiriladi.
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.initialLoading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = state.page + 1;
      final pageData = await _repo.fetch(
        childId: _args.childId,
        period: _args.period,
        region: _args.region,
        page: next,
        limit: _limit,
      );
      // currentChild'ni qayta yozmaymiz — u birinchi sahifada o'rnatilgan va
      // har sahifada bir xil (backend qayta hisoblaydi). Stale bo'lmaydi.
      state = state.copyWith(
        entries: [...state.entries, ...pageData.entries],
        hasMore: pageData.hasMore,
        loadingMore: false,
        page: next,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false, hasMore: false);
    }
  }

  Future<void> refresh() => _loadFirst();
}

final leaderboardProvider = StateNotifierProvider.autoDispose
    .family<LeaderboardNotifier, LeaderboardState, LeaderboardArgs>(
  (ref, args) => LeaderboardNotifier(
    ref.watch(leaderboardRepositoryProvider),
    args,
  ),
);
