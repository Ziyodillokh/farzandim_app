// ─────────────────────────────────────────────────────────────────────
// development_providers — rivojlanish ko'rsatkichi (#63)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/development/data/development_repository.dart';
import 'package:farzandim_child/features/development/data/development_summary.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';

/// Joriy bola rivojlanish ko'rsatkichi (haftalik). childId pairing'dan.
final developmentSummaryProvider =
    FutureProvider<DevelopmentSummary>((ref) async {
  final childId = ref.watch(pairingStateProvider).childId;
  if (childId == null) return DevelopmentSummary.empty;
  return ref.read(developmentRepositoryProvider).fetch(childId);
});
