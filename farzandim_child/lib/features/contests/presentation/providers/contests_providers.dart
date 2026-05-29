// ─────────────────────────────────────────────────────────────────────
// contests_providers — tab state + active/finished lists
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 5.7c: real backend `/api/content/olympiads` ulanishi.
// `backendContestsProvider` fetch qiladi, muvaffaqiyatli bo'lsa shu
// ro'yxat ishlatiladi, aks holda MockContests fallback.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/repositories/contests_backend_repository.dart';

/// 0 — Aktiv, 1 — Yakunlangan
final contestsActiveTabProvider = StateProvider<int>((ref) => 0);

final backendContestsProvider = FutureProvider<ContestBundle>((ref) async {
  final repo = ref.watch(contestsBackendRepositoryProvider);
  return repo.fetchContests();
});

final activeContestsProvider = Provider<List<ContestModel>>((ref) {
  final async = ref.watch(backendContestsProvider);
  return async.maybeWhen(
    data: (bundle) => bundle.active,
    orElse: () => const <ContestModel>[],
  );
});

final finishedContestsProvider = Provider<List<ContestModel>>((ref) {
  final async = ref.watch(backendContestsProvider);
  return async.maybeWhen(
    data: (bundle) => bundle.finished,
    orElse: () => const <ContestModel>[],
  );
});
