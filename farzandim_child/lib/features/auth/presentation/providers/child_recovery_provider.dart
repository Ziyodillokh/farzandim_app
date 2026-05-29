// ─────────────────────────────────────────────────────────────────────
// child_recovery_provider — ChildRecoveryService Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/auth/data/services/child_recovery_service.dart';

final childRecoveryServiceProvider =
    Provider<ChildRecoveryService>((ref) => ChildRecoveryService());
