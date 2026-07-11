// ─────────────────────────────────────────────────────────────────────
// ChildRepositoryProvider — Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/account/data/repositories/child_repository.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

final childRepositoryProvider = Provider<ChildRepository>(
  (ref) => ChildRepository(ref.read(dioClientProvider)),
);

/// Bog'langan ota-onaning ismi (backend'dan). Ulanmagan/xato bo'lsa null —
/// UI "Ota-ona" fallback ko'rsatadi.
final parentNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  final childId = ref.watch(pairingStateProvider).childId;
  if (childId == null) return null;
  try {
    return await ref.read(childRepositoryProvider).getParentName(childId);
  } catch (_) {
    return null;
  }
});
