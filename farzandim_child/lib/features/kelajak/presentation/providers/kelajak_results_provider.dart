// Kelajak natijalari tarixi — kursorli sahifalar (yangisi birinchi).
// Keyingi sahifa `loadMore` bilan; uning xatosi ro'yxatni o'chirmaydi.

import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yuklangan natijalar va keyingi sahifa holati.
class KelajakResultsState {
  const KelajakResultsState({
    required this.items,
    this.nextBefore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<KelajakSessionSummary> items;

  /// Keyingi sahifa kursori (`null` — hammasi yuklangan).
  final String? nextBefore;
  final bool isLoadingMore;

  /// Keyingi sahifani yuklab bo'lmadi (ro'yxat saqlanadi).
  final KelajakException? loadMoreError;

  bool get hasMore => nextBefore != null;
  bool get isEmpty => items.isEmpty;
}

final kelajakResultsProvider =
    AsyncNotifierProvider.autoDispose<
      KelajakResultsNotifier,
      KelajakResultsState
    >(KelajakResultsNotifier.new);

class KelajakResultsNotifier
    extends AutoDisposeAsyncNotifier<KelajakResultsState> {
  /// Har qayta qurilishda / yopilishda oshadi — eski so'rov javobi
  /// yangi ro'yxatga qo'shilmaydi.
  int _generation = 0;

  @override
  Future<KelajakResultsState> build() async {
    ref.onDispose(() => _generation++);
    if (ref.watch(kelajakAccountProvider) == null) {
      throw const KelajakException(KelajakErrorCode.unavailable);
    }
    final page = await ref.watch(kelajakRepositoryProvider).loadResults();
    return KelajakResultsState(items: page.items, nextBefore: page.nextBefore);
  }

  /// Keyingi sahifa (bir vaqtda bittadan; hammasi yuklangan bo'lsa — hech
  /// narsa qilmaydi).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final cursor = current?.nextBefore;
    if (current == null || cursor == null || current.isLoadingMore) return;
    final generation = _generation;
    state = AsyncData(_with(current, isLoadingMore: true));
    try {
      final page = await ref
          .read(kelajakRepositoryProvider)
          .loadResults(before: cursor);
      if (generation != _generation) return;
      state = AsyncData(
        KelajakResultsState(
          items: uniqueBy([...current.items, ...page.items], (s) => s.id),
          nextBefore: page.nextBefore,
        ),
      );
    } on KelajakException catch (e) {
      if (generation != _generation) return;
      state = AsyncData(_with(current, loadMoreError: e));
    }
  }

  static KelajakResultsState _with(
    KelajakResultsState state, {
    bool isLoadingMore = false,
    KelajakException? loadMoreError,
  }) => KelajakResultsState(
    items: state.items,
    nextBefore: state.nextBefore,
    isLoadingMore: isLoadingMore,
    loadMoreError: loadMoreError,
  );
}
