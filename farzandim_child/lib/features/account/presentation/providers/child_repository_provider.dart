// ─────────────────────────────────────────────────────────────────────
// ChildRepositoryProvider — Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/account/data/repositories/child_repository.dart';

final childRepositoryProvider = Provider<ChildRepository>(
  (ref) => ChildRepository(ref.read(dioClientProvider)),
);
