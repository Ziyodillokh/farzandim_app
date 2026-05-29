// ─────────────────────────────────────────────────────────────────────
// ChildRepositoryProvider — Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/account/data/repositories/child_repository.dart';

final childRepositoryProvider =
    Provider<ChildRepository>((ref) => ChildRepository());
