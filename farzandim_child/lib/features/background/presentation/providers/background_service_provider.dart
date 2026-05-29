// ─────────────────────────────────────────────────────────────────────
// BackgroundServiceProvider — Riverpod singletoni
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/background/data/services/background_service.dart';

final backgroundServiceProvider =
    Provider<BackgroundService>((ref) => BackgroundService());
