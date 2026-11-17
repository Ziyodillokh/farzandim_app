// ─────────────────────────────────────────────────────────────────────
// growth_providers — Growth (kunlik testlar) holati, ota-ona ko'rinishi
// ─────────────────────────────────────────────────────────────────────
//
// Xulosa (7/30 kun), profil va natijalar tarixi (`nextBefore` kursori bilan
// sahifalanadi). Backend'da Growth yo'q yoki bola topilmasa (404 `code`siz)
// xulosa `null` — UI kartani yashiradi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/growth/data/learning_repository.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_result.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Xulosa kaliti: bola + davr (`kGrowthPeriods`: 7 yoki 30 kun).
typedef GrowthSummaryArgs = ({String childId, int days});

/// 7 ↔ 30 almashtirilganda yoki ekranga tez qaytilganda qayta yuklanmasin.
const Duration _growthCacheTtl = Duration(minutes: 2);

/// Davr xulosasi; Growth mavjud emas → `null` (karta yashiriladi).
final growthSummaryProvider = FutureProvider.autoDispose
    .family<LearningSummary?, GrowthSummaryArgs>((ref, args) async {
      keepAliveFor(ref, _growthCacheTtl);
      final repo = ref.watch(learningRepositoryProvider);
      try {
        return await repo.fetchSummary(args.childId, days: args.days);
      } on SchoolFailure catch (failure) {
        if (failure.isUnavailable) return null;
        rethrow;
      }
    });

/// Bolaning sinfi va fanlari; hali tanlanmagan → `null`.
final growthProfileProvider = FutureProvider.autoDispose
    .family<LearningProfile?, String>((ref, childId) {
      return ref.watch(learningRepositoryProvider).fetchProfile(childId);
    });

/// Natijalar tarixi holati.
@immutable
class GrowthResultsState {
  const GrowthResultsState({
    this.items = const [],
    this.nextBefore,
    this.initialLoading = true,
    this.loadingMore = false,
    this.failure,
  });

  final List<LearningResult> items;

  /// Keyingi sahifa kursori; oxiriga yetilgan → `null`.
  final String? nextBefore;
  final bool initialLoading;
  final bool loadingMore;

  /// Oxirgi yuklash xatosi. Sahifa xatosidan keyin `loadMore` faqat
  /// foydalanuvchi "qayta urinish"ni bosganda chaqirilsin (avtomatik emas).
  final SchoolFailure? failure;

  bool get hasMore => nextBefore != null;
}

class GrowthResultsNotifier extends StateNotifier<GrowthResultsState> {
  GrowthResultsNotifier(this._repo, this._childId)
    : super(const GrowthResultsState()) {
    unawaited(refresh());
  }

  final LearningRepository _repo;
  final String _childId;

  /// `refresh` paytida kechikkan `loadMore` natijasi qo'shilmasin.
  int _generation = 0;

  /// Birinchi sahifani qayta yuklash (pull-to-refresh).
  Future<void> refresh() async {
    final generation = ++_generation;
    state = GrowthResultsState(items: state.items);
    try {
      final page = await _repo.fetchResults(_childId);
      if (!mounted || generation != _generation) return;
      state = GrowthResultsState(
        items: page.items,
        nextBefore: page.nextBefore,
        initialLoading: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = GrowthResultsState(
        items: state.items,
        initialLoading: false,
        failure: SchoolFailure.fromError(e),
      );
    }
  }

  /// Keyingi sahifa (ro'yxat oxirida).
  Future<void> loadMore() async {
    final cursor = state.nextBefore;
    if (cursor == null || state.loadingMore || state.initialLoading) return;
    final generation = _generation;
    state = GrowthResultsState(
      items: state.items,
      nextBefore: cursor,
      initialLoading: false,
      loadingMore: true,
    );
    try {
      final page = await _repo.fetchResults(_childId, before: cursor);
      if (!mounted || generation != _generation) return;
      state = GrowthResultsState(
        items: List.unmodifiable([...state.items, ...page.items]),
        nextBefore: page.nextBefore,
        initialLoading: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // Kursor saqlanadi — "qayta urinish" shu joydan davom etadi.
      state = GrowthResultsState(
        items: state.items,
        nextBefore: cursor,
        initialLoading: false,
        failure: SchoolFailure.fromError(e),
      );
    }
  }
}

final growthResultsProvider = StateNotifierProvider.autoDispose
    .family<GrowthResultsNotifier, GrowthResultsState, String>(
      (ref, childId) =>
          GrowthResultsNotifier(ref.watch(learningRepositoryProvider), childId),
    );

/// Growth amallari (ota-ona bolaning sinfi va fanlarini o'zgartiradi).
class GrowthActionsNotifier extends StateNotifier<AsyncValue<void>> {
  GrowthActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Saqlash; muvaffaqiyatda profil va xulosa qayta yuklanadi.
  Future<Result<LearningProfile>> saveProfile(
    String childId,
    LearningProfile profile,
  ) async {
    state = const AsyncValue.loading();
    try {
      final saved = await _ref
          .read(learningRepositoryProvider)
          .saveProfile(childId, profile);
      state = const AsyncValue.data(null);
      _ref
        ..invalidate(growthProfileProvider(childId))
        ..invalidate(growthSummaryProvider);
      return Result.success(saved);
    } catch (e, st) {
      final failure = SchoolFailure.fromError(e);
      state = AsyncValue.error(failure, st);
      return Result.failure(failure.messageKey.tr());
    }
  }
}

final growthActionsProvider =
    StateNotifierProvider<GrowthActionsNotifier, AsyncValue<void>>(
      GrowthActionsNotifier.new,
    );
